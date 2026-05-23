require "duckdb"

module ConnectorAdapters
  # DuckDB Source Adapter - for reading from persisted DuckDB database files
  # This is separate from DuckdbAdapter which is used for in-memory transformations
  class DuckdbSourceAdapter < BaseAdapter
    class DuckDBSourceError < AdapterError; end

    attr_reader :db, :connection

    def initialize(connector)
      super(connector)
      @db = nil
      @connection = nil
    end

    # Read data from a DuckDB database file
    # @param query [String] SQL query to execute
    # @return [Array<Hash>] Query results
    def read_data(query:, **_options)
      ensure_connected!

      log_info("Executing query on DuckDB database: #{query.truncate(200)}")

      start_time = Time.current
      result = connection.query(query)
      execution_time = ((Time.current - start_time) * 1000).round(2)

      # Get column names from result
      columns = result.columns.map(&:name)

      # Convert result rows (arrays) to array of hashes
      rows = result.map do |row_array|
        columns.zip(row_array).to_h
      end

      log_info("Query returned #{rows.size} rows in #{execution_time}ms")
      rows
    rescue StandardError => e
      log_error("Failed to read data: #{e.message}")
      raise DuckDBSourceError, "Failed to read from DuckDB: #{e.message}"
    end

    # Write data to DuckDB database (not typically used for source connectors)
    def write_data(table_name:, data:, write_disposition: :append, **_options)
      ensure_connected!

      log_info("Writing #{data.size} rows to DuckDB table '#{table_name}'")

      case write_disposition.to_sym
      when :truncate_and_load
        connection.query("DROP TABLE IF EXISTS #{table_name}")
      when :merge
        raise NotImplementedError, "Merge write disposition not implemented for DuckDB"
      end

      return 0 if data.empty?

      # Create table if it doesn't exist
      first_row = data.first
      columns = first_row.keys

      create_table_sql = build_create_table_sql(table_name, first_row)
      connection.query(create_table_sql)

      # Insert data in batches
      batch_size = 1000
      data.each_slice(batch_size) do |batch|
        insert_batch(table_name, batch)
      end

      log_info("Successfully wrote #{data.size} rows to '#{table_name}'")
      { rows_affected: data.size }
    rescue StandardError => e
      log_error("Failed to write data: #{e.message}")
      raise DuckDBSourceError, "Failed to write to DuckDB: #{e.message}"
    end

    # Test connection to DuckDB database
    def test_connection
      ensure_connected!
      connection.query("SELECT 1").first[0] == 1
    rescue StandardError => e
      log_error("Connection test failed: #{e.message}")
      false
    end

    # Get schema for a table in the DuckDB database
    def get_schema(table_name:)
      ensure_connected!

      result = connection.query("DESCRIBE #{table_name}")
      result.map do |row|
        { name: row[0], type: row[1] }
      end
    rescue StandardError => e
      log_error("Failed to get schema: #{e.message}")
      []
    end

    # List all tables in the DuckDB database
    def list_tables
      ensure_connected!

      result = connection.query("SHOW TABLES")
      result.map { |row| row[0] }
    rescue StandardError => e
      log_error("Failed to list tables: #{e.message}")
      []
    end

    # Close the connection
    def close
      if @connection
        @connection.disconnect
        @connection = nil
      end
      if @db
        @db.close
        @db = nil
      end
      log_info("Closed DuckDB connection")
    end

    protected

    def validate_config!
      unless connector.config["database_path"].present?
        raise ConfigurationError, "DuckDB connector requires 'database_path' in config"
      end

      database_path = connector.config["database_path"]
      unless File.exist?(database_path)
        raise ConfigurationError, "DuckDB database file not found: #{database_path}"
      end
    end

    private

    def ensure_connected!
      return if @connection

      validate_config!
      database_path = connector.config["database_path"]

      log_info("Opening DuckDB database: #{database_path}")
      @db = DuckDB::Database.open(database_path)
      @connection = @db.connect
      log_info("Connected to DuckDB database")
    rescue StandardError => e
      log_error("Failed to connect: #{e.message}")
      raise DuckDBSourceError, "Failed to connect to DuckDB: #{e.message}"
    end

    def build_create_table_sql(table_name, sample_row)
      columns = sample_row.map do |key, value|
        type = infer_duckdb_type(value)
        "#{sanitize_column_name(key)} #{type}"
      end.join(", ")

      "CREATE TABLE IF NOT EXISTS #{table_name} (#{columns})"
    end

    def infer_duckdb_type(value)
      case value
      when Integer
        "BIGINT"
      when Float
        "DOUBLE"
      when TrueClass, FalseClass
        "BOOLEAN"
      when Date
        "DATE"
      when Time, DateTime
        "TIMESTAMP"
      when nil
        "VARCHAR"
      else
        "VARCHAR"
      end
    end

    def sanitize_column_name(name)
      "\"#{name.to_s.gsub('"', '""')}\""
    end

    def insert_batch(table_name, batch)
      return if batch.empty?

      columns = batch.first.keys
      column_names = columns.map { |k| sanitize_column_name(k) }.join(", ")
      placeholders = columns.map { "?" }.join(", ")

      insert_sql = "INSERT INTO #{table_name} (#{column_names}) VALUES (#{placeholders})"

      batch.each do |row|
        values = columns.map { |col| row[col] }
        connection.query(insert_sql, *values)
      end
    end
  end
end
