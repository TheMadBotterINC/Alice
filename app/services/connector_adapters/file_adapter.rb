require "csv"
require "roo"
require "caxlsx"

module ConnectorAdapters
  class FileAdapter < BaseAdapter
    # Read data from CSV, TSV, or Excel file
    #
    # Options:
    #   query: Not used for file connectors
    #   uploaded_file: ActiveStorage::Blob for upload mode (optional)
    def read_data(query: nil, uploaded_file: nil)
      if uploaded_file.present?
        # Reading from uploaded file (upload mode)
        log_info("Reading data from uploaded file: #{uploaded_file.filename}")
        read_from_uploaded_file(uploaded_file)
      else
        # Reading from file path (file_path mode)
        file_path = resolve_file_path(config["file_path"])

        log_info("Reading data from file: #{file_path}")

        unless File.exist?(file_path)
          raise ConnectionError, "File not found: #{file_path}"
        end

        case file_extension(file_path)
        when ".csv"
          read_csv(file_path)
        when ".tsv", ".txt"
          read_tsv(file_path)
        when ".xlsx", ".xls"
          read_excel(file_path)
        else
          raise ConnectionError, "Unsupported file format: #{file_extension(file_path)}"
        end
      end
    rescue StandardError => e
      log_error("Failed to read file: #{e.message}")
      raise QueryError, e.message
    end

    # Write data to CSV, TSV, or Excel file
    def write_data(table_name:, data:, write_disposition: :append, schema: nil)
      return { rows_affected: 0, message: "No data to write" } if data.empty?

      # Use table_name as filename (sanitized)
      file_name = "#{sanitize_filename(table_name)}#{config['file_extension'] || '.csv'}"
      output_dir = resolve_file_path(config["output_directory"] || "data/output")
      file_path = File.join(output_dir, file_name)

      log_info("Writing #{data.size} rows to #{file_path}")

      # Create directory if it doesn't exist
      FileUtils.mkdir_p(File.dirname(file_path))

      # Handle write disposition
      mode = (write_disposition.to_sym == :append && File.exist?(file_path)) ? "a" : "w"

      case file_extension(file_path)
      when ".csv"
        write_csv(file_path, data, mode)
      when ".tsv", ".txt"
        write_tsv(file_path, data, mode)
      when ".xlsx"
        write_excel(file_path, data, write_disposition)
      else
        raise ConnectionError, "Unsupported output format: #{file_extension(file_path)}"
      end

      {
        rows_affected: data.size,
        file_path: file_path,
        write_disposition: write_disposition,
        message: "Successfully wrote #{data.size} rows to #{file_path}"
      }
    rescue StandardError => e
      log_error("Failed to write file: #{e.message}")
      raise QueryError, e.message
    end

    def test_connection
      log_info("Testing file connector")

      # For upload mode connectors, always return true since file is provided at runtime
      if config["mode"] == "upload"
        log_info("Upload mode connector - file will be provided at pipeline run time")
        return true
      end

      if config["file_path"].present?
        # Test reading
        file_path = resolve_file_path(config["file_path"])
        if File.exist?(file_path)
          log_info("File exists and is accessible: #{file_path}")
          true
        else
          log_error("File not found: #{file_path}")
          false
        end
      elsif config["output_directory"].present?
        # Test writing
        output_dir = resolve_file_path(config["output_directory"])
        FileUtils.mkdir_p(output_dir)
        log_info("Output directory is accessible: #{output_dir}")
        true
      else
        log_error("No file_path or output_directory configured")
        false
      end
    rescue => e
      log_error("Connection test failed: #{e.message}")
      false
    end

    protected

    def validate_config!
      super

      # Skip validation for upload mode - file provided at runtime
      return if config["mode"] == "upload"

      if config["file_path"].blank? && config["output_directory"].blank?
        raise ConnectionError, "Either file_path or output_directory must be specified"
      end
    end

    private

    def config
      @config ||= connector.config.with_indifferent_access
    end

    # Read CSV file
    def read_csv(file_path)
      rows = []
      CSV.foreach(file_path, headers: true, header_converters: :symbol) do |row|
        rows << row.to_h.stringify_keys
      end
      log_info("Read #{rows.size} rows from CSV")
      rows
    end

    # Read TSV file
    def read_tsv(file_path)
      rows = []
      CSV.foreach(file_path, headers: true, header_converters: :symbol, col_sep: "\t") do |row|
        rows << row.to_h.stringify_keys
      end
      log_info("Read #{rows.size} rows from TSV")
      rows
    end

    # Read Excel file
    def read_excel(file_path)
      spreadsheet = Roo::Spreadsheet.open(file_path)
      sheet = spreadsheet.sheet(0)  # First sheet

      headers = sheet.row(1).map(&:to_s)
      rows = []

      (2..sheet.last_row).each do |i|
        row_data = {}
        headers.each_with_index do |header, j|
          row_data[header] = sheet.cell(i, j + 1)&.to_s
        end
        rows << row_data
      end

      log_info("Read #{rows.size} rows from Excel")
      rows
    end

    # Read from ActiveStorage uploaded file
    def read_from_uploaded_file(blob)
      # Download to temp file
      tempfile = Tempfile.new([ "upload", File.extname(blob.filename.to_s) ])
      begin
        blob.download { |chunk| tempfile.write(chunk) }
        tempfile.rewind
        tempfile.close

        # Auto-detect format from file extension
        detected_format = detect_file_format(tempfile.path, blob.filename.to_s)
        log_info("Auto-detected format: #{detected_format} for file: #{blob.filename}")

        # Read based on detected format
        case detected_format
        when :csv
          read_csv(tempfile.path)
        when :tsv
          read_tsv(tempfile.path)
        when :excel
          read_excel(tempfile.path)
        else
          raise ConnectionError, "Unsupported uploaded file format: #{blob.filename} (detected: #{detected_format})"
        end
      ensure
        tempfile.unlink if tempfile
      end
    end

    # Auto-detect file format from extension and optionally content
    def detect_file_format(file_path, filename)
      ext = file_extension(file_path).downcase

      case ext
      when ".csv"
        :csv
      when ".tsv", ".txt"
        # Check if it's actually TSV by examining first line
        first_line = File.open(file_path, &:readline) rescue ""
        if first_line.include?("\t")
          :tsv
        else
          # Might be CSV with .txt extension
          :csv
        end
      when ".xlsx", ".xls", ".xlsm"
        :excel
      else
        # Try to detect from content
        first_line = File.open(file_path, &:readline) rescue ""
        if first_line.include?("\t")
          :tsv
        elsif first_line.include?(",")
          :csv
        else
          :unknown
        end
      end
    end

    # Write CSV file
    def write_csv(file_path, data, mode)
      CSV.open(file_path, mode) do |csv|
        if mode == "w" || !File.exist?(file_path) || File.zero?(file_path)
          # Write headers
          csv << data.first.keys
        end

        # Write data rows
        data.each do |row|
          csv << row.values
        end
      end

      log_info("Wrote #{data.size} rows to CSV")
    end

    # Write TSV file
    def write_tsv(file_path, data, mode)
      CSV.open(file_path, mode, col_sep: "\t") do |tsv|
        if mode == "w" || !File.exist?(file_path) || File.zero?(file_path)
          # Write headers
          tsv << data.first.keys
        end

        # Write data rows
        data.each do |row|
          tsv << row.values
        end
      end

      log_info("Wrote #{data.size} rows to TSV")
    end

    # Write Excel file
    def write_excel(file_path, data, write_disposition)
      package = Axlsx::Package.new
      workbook = package.workbook

      workbook.add_worksheet(name: "Data") do |sheet|
        # Add header row
        sheet.add_row data.first.keys

        # Add data rows
        data.each do |row|
          sheet.add_row row.values
        end
      end

      package.serialize(file_path)
      log_info("Wrote #{data.size} rows to Excel")
    end

    def resolve_file_path(path)
      return path if Pathname.new(path).absolute?
      Rails.root.join(path).to_s
    end

    def file_extension(path)
      File.extname(path).downcase
    end

    def sanitize_filename(name)
      name.to_s.gsub(/[^a-zA-Z0-9_-]/, "_").gsub(/__+/, "_")
    end
  end
end
