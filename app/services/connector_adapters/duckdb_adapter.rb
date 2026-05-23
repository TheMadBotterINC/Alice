require "duckdb"

module ConnectorAdapters
  class DuckdbAdapter < BaseAdapter
    class DuckDBError < AdapterError; end

    attr_reader :db, :connection

    def initialize(connector = nil)
      # DuckDB adapter doesn't need a connector since it's in-memory/local
      @connector = connector
      @db = DuckDB::Database.open # In-memory database
      @connection = @db.connect
      log_info("Initialized DuckDB in-memory database")
    end

    # Load data into DuckDB from a hash/array structure
    # @param table_name [String] Name of the table to create
    # @param data [Array<Hash>] Array of row hashes
    # @return [Integer] Number of rows loaded
    def load_data(table_name:, data:)
      return 0 if data.empty?

      log_info("Loading #{data.size} rows into DuckDB table '#{table_name}'")

      # Infer schema from first row
      first_row = data.first
      columns = first_row.keys

      # Create table with inferred types
      create_table_sql = build_create_table_sql(table_name, first_row)
      connection.query(create_table_sql)
      log_info("Created table '#{table_name}' with columns: #{columns.join(', ')}")

      # Insert data in batches
      batch_size = 1000
      data.each_slice(batch_size).with_index do |batch, idx|
        insert_batch(table_name, batch)
        log_info("Inserted batch #{idx + 1} (#{batch.size} rows)") if (idx + 1) % 10 == 0
      end

      log_info("Successfully loaded #{data.size} rows into '#{table_name}'")
      data.size
    rescue StandardError => e
      log_error("Failed to load data: #{e.message}")
      raise DuckDBError, "Failed to load data into DuckDB: #{e.message}"
    end

    # Execute a SQL query in DuckDB
    # @param sql [String] SQL query to execute
    # @return [Hash] Query results with :rows, :row_count, :execution_time_ms
    def execute_query(sql:)
      log_info("Executing SQL query in DuckDB")
      log_info("SQL: #{sql.truncate(200)}")

      start_time = Time.current
      result = connection.query(sql)
      execution_time = ((Time.current - start_time) * 1000).round(2)

      # Get column names from result
      columns = result.columns.map(&:name)

      # Convert result rows (arrays) to array of hashes
      rows = result.map do |row_array|
        columns.zip(row_array).to_h
      end

      log_info("Query executed successfully in #{execution_time}ms, returned #{rows.size} rows")

      {
        rows: rows,
        row_count: rows.size,
        execution_time_ms: execution_time
      }
    rescue StandardError => e
      log_error("Query execution failed: #{e.message}")
      raise QueryError, "DuckDB query failed: #{e.message}"
    end

    # Export data from a DuckDB table
    # @param table_name [String] Name of the table to export
    # @return [Array<Hash>] All rows from the table
    def export_table(table_name:)
      log_info("Exporting data from table '#{table_name}'")

      result = connection.query("SELECT * FROM #{table_name}")
      columns = result.columns.map(&:name)

      rows = result.map do |row_array|
        columns.zip(row_array).to_h
      end

      log_info("Exported #{rows.size} rows from '#{table_name}'")
      rows
    rescue StandardError => e
      log_error("Failed to export table: #{e.message}")
      raise DuckDBError, "Failed to export table: #{e.message}"
    end

    # Get list of tables in the DuckDB instance
    # @return [Array<String>] Table names
    def list_tables
      result = connection.query("SHOW TABLES")
      result.map { |row| row[0] }
    end

    # Close the DuckDB connection
    def close
      connection&.disconnect
      log_info("Closed DuckDB connection")
    end

    # Implementation of BaseAdapter interface
    def read_data(query: nil)
      execute_query(sql: query)[:rows]
    end

    def write_data(table_name:, data:, write_disposition: :append)
      load_data(table_name: table_name, data: data)
    end

    def test_connection
      # DuckDB is always available (in-memory)
      connection.query("SELECT 1").first[0] == 1
    rescue StandardError
      false
    end

    def get_schema(table_name: nil)
      return [] unless table_name

      result = connection.query("DESCRIBE #{table_name}")
      result.map do |row|
        { name: row[0], type: row[1] }
      end
    rescue StandardError => e
      log_error("Failed to get schema: #{e.message}")
      []
    end

    protected

    def validate_config!
      # DuckDB doesn't need config validation
      true
    end

    private

    # Build CREATE TABLE SQL with inferred types
    def build_create_table_sql(table_name, sample_row)
      columns = sample_row.map do |key, value|
        type = infer_duckdb_type(value)
        "#{sanitize_column_name(key)} #{type}"
      end.join(", ")

      "CREATE TABLE #{table_name} (#{columns})"
    end

    # Infer DuckDB type from Ruby value
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
        "VARCHAR" # Default for null values
      else
        "VARCHAR"
      end
    end

    # Sanitize column names to be SQL-safe
    def sanitize_column_name(name)
      # Replace invalid characters and wrap in quotes
      "\"#{name.to_s.gsub('"', '""')}\""
    end

    # Insert a batch of rows into a table
    def insert_batch(table_name, batch)
      return if batch.empty?

      columns = batch.first.keys
      column_names = columns.map { |k| sanitize_column_name(k) }.join(", ")
      placeholders = columns.map { "?" }.join(", ")

      insert_sql = "INSERT INTO #{table_name} (#{column_names}) VALUES (#{placeholders})"

      # Insert each row individually using parameterized queries
      batch.each do |row|
        values = columns.map { |col| row[col] }
        connection.query(insert_sql, *values)
      end
    end

    # Format a value for SQL insertion
    def format_value(value)
      case value
      when nil
        "NULL"
      when String
        "'#{value.gsub("'", "''")}'"
      when Date
        "'#{value.strftime('%Y-%m-%d')}'"
      when Time, DateTime
        "'#{value.strftime('%Y-%m-%d %H:%M:%S')}'"
      when TrueClass, FalseClass
        value.to_s.upcase
      else
        value.to_s
      end
    end
  end
end
