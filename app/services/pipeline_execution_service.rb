class PipelineExecutionService
  class ExecutionError < StandardError; end
  class ConfigurationError < StandardError; end

  attr_reader :pipeline, :pipeline_run, :duckdb

  def initialize(pipeline_run:)
    @pipeline_run = pipeline_run
    @pipeline = pipeline_run.pipeline
    @duckdb = nil

    validate_pipeline!
  end

  # Execute the pipeline: load sources -> transform in DuckDB -> write to destination
  def execute
    log_info("Starting pipeline execution for '#{pipeline.name}'")

    begin
      # Initialize DuckDB for transformation
      @duckdb = ConnectorAdapters::DuckdbAdapter.new

      # Step 1: Load data from all source connectors into DuckDB
      load_sources

      # Step 2: Execute transformation SQL in DuckDB
      transformation_result = execute_transformation

      # Step 3: Write results to destination (if configured) or generate file export
      destination_result = if pipeline.file_export?
        write_to_file_export(transformation_result[:rows])
      elsif has_destination?
        write_to_destination(transformation_result[:rows])
      end

      # Build success summary
      sources_count = pipeline.source_connectors.count + pipeline.source_datasets.count
      {
        success: true,
        sources_loaded: sources_count,
        transformation_rows: transformation_result[:row_count],
        execution_time_ms: transformation_result[:execution_time_ms],
        destination_rows: destination_result&.dig(:rows_affected) || 0,
        message: build_success_message(transformation_result, destination_result)
      }

    rescue StandardError => e
      log_error("Pipeline execution failed: #{e.message}")
      log_error(e.backtrace.first(5).join("\n"))
      raise ExecutionError, "Pipeline execution failed: #{e.message}"
    ensure
      # Always close DuckDB connection
      duckdb&.close
    end
  end

  private

  def validate_pipeline!
    if pipeline.source_connectors.empty? && pipeline.source_datasets.empty?
      raise ConfigurationError, "Pipeline has no sources configured"
    end

    unless pipeline.transformation_sql.present?
      raise ConfigurationError, "Pipeline has no transformation SQL configured"
    end
  end

  def load_sources
    total_sources = pipeline.source_connectors.count + pipeline.source_datasets.count
    log_info("Loading data from #{total_sources} source(s)")
    log_info("="*80)
    log_info("AVAILABLE TABLES IN DUCKDB (use these names in your SQL):")
    log_info("="*80)

    # Load data from connector sources
    pipeline.pipeline_sources.where.not(connector_id: nil).each_with_index do |pipeline_source, index|
      connector = pipeline_source.connector
      connector_start = Time.current
      log_info("\n⏱️  Loading connector source #{index + 1}: #{connector.name} (#{connector.connector_type})")

      # Get adapter for the source connector
      adapter = get_adapter_for_connector(connector)

      # For upload mode connectors, get the uploaded file
      uploaded_file = nil
      if connector.upload_mode?
        uploaded_file = pipeline_run.source_files[index] if pipeline_run.source_files.attached?
        if uploaded_file.blank?
          raise ConfigurationError, "Upload connector '#{connector.name}' requires a file upload but none was provided"
        end
        log_info("Using uploaded file: #{uploaded_file.filename}")
      end

      # Build source query with smart defaults (not used for file connectors)
      # File connectors process entire file without limits
      source_query = build_source_query(connector)
      log_info("Source query: #{source_query.truncate(200)}") if source_query.present?

      # Read data from source (pass uploaded_file for upload mode)
      read_start = Time.current
      source_data = adapter.read_data(query: source_query, uploaded_file: uploaded_file)
      read_duration = Time.current - read_start
      log_info("⏱️  Read #{source_data.size} rows from '#{connector.name}' in #{read_duration.round(2)}s")

      # Use the table_alias from pipeline_source as the table name in DuckDB
      table_name = pipeline_source.table_alias

      # Load into DuckDB
      load_start = Time.current
      rows_loaded = duckdb.load_data(table_name: table_name, data: source_data)
      load_duration = Time.current - load_start
      connector_duration = Time.current - connector_start

      log_info("✓ Table '#{table_name}' (#{rows_loaded} rows) - use in SQL: FROM #{table_name}")
      log_info("⏱️  DuckDB load took #{load_duration.round(2)}s")
      log_info("⏱️  Total time for connector source: #{connector_duration.round(2)}s")

      # Close adapter to release resources
      adapter.close if adapter.respond_to?(:close)
    end

    # Load data from dataset sources
    pipeline.pipeline_sources.where.not(dataset_id: nil).each_with_index do |pipeline_source, index|
      dataset = pipeline_source.dataset
      dataset_start = Time.current
      log_info("\n⏱️  Loading dataset source #{index + 1}: #{dataset.name} (#{dataset.fully_qualified_name})")

      # Get the connector adapter for the dataset's underlying connector
      adapter = get_adapter_for_connector(dataset.connector)

      # Build query to read from the dataset's table
      row_limit = pipeline.source_row_limit
      
      # Build query based on connector type
      source_query = if dataset.connector.connector_type == "duckdb"
        # For DuckDB, use simple table name
        "SELECT * FROM #{dataset.table_name} LIMIT #{row_limit}"
      else
        # For other databases (Snowflake, etc), use full database.schema.table format
        "SELECT * FROM #{dataset.connector.config['database']}.#{dataset.schema_name}.#{dataset.table_name} LIMIT #{row_limit}"
      end
      
      log_info("Applying row limit of #{row_limit} rows to dataset source")
      log_info("Dataset query: #{source_query}")

      # Read data from the dataset
      read_start = Time.current
      source_data = adapter.read_data(query: source_query)
      read_duration = Time.current - read_start
      log_info("⏱️  Read #{source_data.size} rows from dataset '#{dataset.name}' in #{read_duration.round(2)}s")

      # Use the table_alias from pipeline_source as the table name in DuckDB
      table_name = pipeline_source.table_alias

      # Load into DuckDB
      load_start = Time.current
      rows_loaded = duckdb.load_data(table_name: table_name, data: source_data)
      load_duration = Time.current - load_start
      dataset_duration = Time.current - dataset_start

      log_info("✓ Table '#{table_name}' (#{rows_loaded} rows) - use in SQL: FROM #{table_name}")
      log_info("⏱️  DuckDB load took #{load_duration.round(2)}s")
      log_info("⏱️  Total time for dataset source: #{dataset_duration.round(2)}s")

      # Close adapter to release resources
      adapter.close if adapter.respond_to?(:close)
    end

    log_info("="*80)
    log_info("All sources loaded successfully")
  end

  def execute_transformation
    log_info("Executing transformation SQL")
    log_info("SQL: #{pipeline.transformation_sql.truncate(500)}")

    result = duckdb.execute_query(sql: pipeline.transformation_sql)

    log_info("Transformation completed: #{result[:row_count]} rows generated in #{result[:execution_time_ms]}ms")
    result
  end

  def write_to_destination(result_data)
    return nil unless has_destination?

    if pipeline.destination_dataset.present?
      write_to_dataset(result_data)
    elsif pipeline.destination_connector.present?
      write_to_connector(result_data)
    end
  end

  def write_to_dataset(result_data)
    dataset = pipeline.destination_dataset
    log_info("Writing #{result_data.size} rows to destination dataset '#{dataset.name}'")
    log_info("Target: #{dataset.source_table_path}")

    adapter = get_adapter_for_connector(dataset.connector)

    # Use dataset's table name and schema
    table_name = dataset.table_name
    schema_name = dataset.schema_name

    # Write with configured disposition
    write_disposition = pipeline.write_disposition || :append
    result = adapter.write_data(
      table_name: table_name,
      data: result_data,
      write_disposition: write_disposition,
      schema: { schema: schema_name, merge_key: pipeline.merge_key }.compact
    )

    log_info("Successfully wrote #{result[:rows_affected]} rows to '#{dataset.source_table_path}'")
    adapter.close if adapter.respond_to?(:close)
    result
  end

  def write_to_connector(result_data)
    connector = pipeline.destination_connector
    log_info("Writing #{result_data.size} rows to destination connector '#{connector.name}' (#{connector.connector_type})")

    adapter = get_adapter_for_connector(connector)

    # Build write options based on connector type
    write_options = build_write_options_for_connector(connector, result_data)

    result = adapter.write_data(**write_options)

    log_info("Successfully wrote #{result[:rows_affected]} rows to '#{connector.name}'")
    adapter.close if adapter.respond_to?(:close)
    result
  end

  def build_write_options_for_connector(connector, result_data)
    case connector.connector_type
    when "powerbi"
      # Power BI requires workspace_id, dataset_name, and optional table_name from destination_config
      config = pipeline.destination_config.with_indifferent_access

      unless config[:workspace_id].present?
        raise ConfigurationError, "Power BI destination requires workspace_id in destination_config"
      end

      unless config[:dataset_name].present?
        raise ConfigurationError, "Power BI destination requires dataset_name in destination_config"
      end

      {
        workspace_id: config[:workspace_id],
        dataset_name: config[:dataset_name],
        table_name: config[:table_name].presence || "data",
        data: result_data,
        write_disposition: pipeline.write_disposition || :append
      }
    when "looking_glass"
      # Looking Glass has a simpler interface
      {
        table_name: determine_destination_table_name,
        data: result_data,
        write_disposition: pipeline.write_disposition || :append
      }
    else
      # Standard write options for other connectors (Snowflake, PostgreSQL, etc.)
      {
        table_name: determine_destination_table_name,
        data: result_data,
        write_disposition: pipeline.write_disposition || :append,
        schema: { merge_key: pipeline.merge_key }.compact
      }
    end
  end


  def write_csv_file(file_path, result_data, config)
    require "csv"

    delimiter = config["delimiter"] || ","
    has_header = config["has_header"].to_s == "true" || config["has_header"] == true
    high_precision = config["high_precision"].to_s == "true" || config["high_precision"] == true

    CSV.open(file_path, "w", col_sep: delimiter) do |csv|
      # Write header if data has column names
      if has_header && result_data.first.is_a?(Hash)
        csv << result_data.first.keys
      end

      # Write data rows
      result_data.each do |row|
        values = row.is_a?(Hash) ? row.values : row
        
        # Round floating point numbers unless high_precision is enabled
        unless high_precision
          values = values.map do |value|
            if value.is_a?(Float) && value.finite?
              # Round to 6 decimal places and strip trailing zeros
              rounded = value.round(6)
              # Convert to string and remove unnecessary trailing zeros
              rounded.to_s.sub(/\.0+$/, "").sub(/(\.\d*[1-9])0+$/, "\\1")
            else
              value
            end
          end
        end
        
        csv << values
      end
    end

    result_data.size
  end

  def write_excel_file(file_path, result_data, config)
    require "caxlsx"

    has_header = config["has_header"].to_s == "true" || config["has_header"] == true
    sheet_name = config["sheet_name"].presence || "Sheet1"
    high_precision = config["high_precision"].to_s == "true" || config["high_precision"] == true

    package = Axlsx::Package.new
    workbook = package.workbook

    workbook.add_worksheet(name: sheet_name) do |sheet|
      # Write header if data has column names
      if has_header && result_data.first.is_a?(Hash)
        sheet.add_row result_data.first.keys
      end

      # Write data rows
      result_data.each do |row|
        values = row.is_a?(Hash) ? row.values : row
        
        # Round floating point numbers unless high_precision is enabled
        unless high_precision
          values = values.map do |value|
            if value.is_a?(Float) && value.finite?
              value.round(6)
            else
              value
            end
          end
        end
        
        sheet.add_row(values)
      end
    end

    package.serialize(file_path)
    result_data.size
  end

  def write_to_file_export(result_data)
    format = pipeline.export_format
    options = pipeline.export_options_hash

    # Generate a temp file
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    safe_name = sanitize_table_name(pipeline.name)
    ext = format == "excel" ? "xlsx" : "csv"

    temp_path = Rails.root.join("tmp", "#{timestamp}_#{safe_name}.#{ext}").to_s
    FileUtils.mkdir_p(File.dirname(temp_path))

    rows_written = 0
    if format == "excel"
      rows_written = write_excel_file(temp_path, result_data, {
        "sheet_name" => options["sheet_name"] || "Sheet1",
        "has_header" => options["has_header"],
        "high_precision" => options["high_precision"]
      })
    else
      rows_written = write_csv_file(temp_path, result_data, {
        "delimiter" => options["delimiter"] || ",",
        "has_header" => options["has_header"],
        "high_precision" => options["high_precision"]
      })
    end

    # Attach to pipeline_run via ActiveStorage
    filename = File.basename(temp_path)
    pipeline_run.output_file.attach(
      io: File.open(temp_path),
      filename: filename,
      content_type: (format == "excel" ? "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" : "text/csv")
    )

    # Remove temp file
    File.delete(temp_path) if File.exist?(temp_path)

    { rows_affected: rows_written }
  end

  def has_destination?
    pipeline.destination_dataset.present? || pipeline.destination_connector.present?
  end

  def get_adapter_for_connector(connector)
    case connector.connector_type
    when "snowflake"
      ConnectorAdapters::SnowflakeAdapter.new(connector)
    when "file_csv", "file_excel"
      ConnectorAdapters::FileAdapter.new(connector)
    when "postgresql"
      ConnectorAdapters::PostgresqlAdapter.new(connector)
    when "duckdb"
      ConnectorAdapters::DuckdbSourceAdapter.new(connector)
    else
      raise ConfigurationError, "Unsupported connector type: #{connector.connector_type}"
    end
  end

  def build_source_query(connector)
    # For database connectors (Snowflake), we cannot query without knowing which table to use
    # File connectors don't use queries - they read the entire file

    case connector.connector_type
    when "snowflake"
      # Database connectors need a specific table to query
      # Users should use dataset sources instead of raw connector sources for databases
      raise ConfigurationError, <<~MSG.strip
        Cannot use Snowflake connector '#{connector.name}' directly as a source.

        Snowflake connectors need a specific table to query from.
        Please use a Dataset as your source instead:

        1. Go to Connectors → '#{connector.name}' → Browse Tables
        2. Register the table you want to use as a Dataset
        3. Edit this pipeline and select that Dataset as a source

        File connectors (CSV/Excel) can be used directly, but database connectors require a Dataset.
      MSG
    when "file_csv", "file_excel", "file_upload"
      # File connectors don't use queries - read_data handles the file directly
      # Process entire file without row limits
      nil
    else
      # For other connector types, implement as needed
      raise ConfigurationError, "Source query building not implemented for #{connector.connector_type}"
    end
  end

  def sanitize_table_name(name)
    # Convert to lowercase, replace spaces/special chars with underscores
    name.to_s.downcase.gsub(/[^a-z0-9_]/, "_").gsub(/__+/, "_")
  end

  def determine_destination_table_name
    # Could be enhanced to use a pipeline config field
    # For now, use sanitized pipeline name
    sanitize_table_name(pipeline.name)
  end

  def build_success_message(transformation_result, destination_result)
    msg = "Pipeline executed successfully. "
    msg += "Transformed #{transformation_result[:row_count]} rows "
    msg += "in #{transformation_result[:execution_time_ms]}ms. "

    if pipeline.file_export?
      msg += "Generated file for download."
    elsif destination_result
      msg += "Wrote #{destination_result[:rows_affected]} rows to destination."
    else
      msg += "No destination configured."
    end

    msg
  end

  def log_info(message)
    Rails.logger.info("[PipelineExecutionService] #{message}")
  end

  def log_error(message)
    Rails.logger.error("[PipelineExecutionService] #{message}")
  end
end
