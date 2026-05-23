require "duckdb"

class DuckDbEngine
  class EngineError < StandardError; end
  class QueryError < EngineError; end
  class TableLoadError < EngineError; end

  attr_reader :database, :connection

  def initialize
    @database = DuckDB::Database.open # In-memory database
    @connection = @database.connect
    @loaded_tables = {}

    log_info("DuckDB in-memory database initialized")
  end

  # Load a table into DuckDB from an array of hashes
  # @param table_name [String] Name of the table in DuckDB
  # @param data [Array<Hash>] Array of row hashes
  # @return [Integer] Number of rows loaded
  def load_table(table_name, data)
    raise TableLoadError, "Table name is required" if table_name.blank?
    raise TableLoadError, "Data must be an array" unless data.is_a?(Array)
    return 0 if data.empty?

    log_info("Loading table '#{table_name}' with #{data.size} rows")

    # Get column names from first row
    columns = data.first.keys

    # Create table with inferred types
    create_table_sql = build_create_table_sql(table_name, data.first)
    execute_sql(create_table_sql)

    # Insert data in batches for better performance
    batch_size = 1000
    data.each_slice(batch_size) do |batch|
      insert_batch(table_name, columns, batch)
    end

    @loaded_tables[table_name] = { row_count: data.size, columns: columns }
    log_info("Table '#{table_name}' loaded successfully with #{data.size} rows")

    data.size
  end

  # Execute a SQL query and return results as array of hashes
  # @param sql [String] SQL query to execute
  # @return [Array<Hash>] Array of row hashes
  def query(sql)
    raise QueryError, "SQL query is required" if sql.blank?

    log_info("Executing query: #{sql[0..100]}#{'...' if sql.length > 100}")

    result = @connection.query(sql)
    rows = []

    # Get column names from result (DuckDB::Column objects)
    column_objects = result.columns
    column_names = column_objects.map { |col| col.respond_to?(:name) ? col.name : col.to_s }

    # DuckDB gem returns rows as arrays, convert to hashes
    result.each do |row_array|
      row_hash = {}
      column_names.each_with_index do |col_name, idx|
        row_hash[col_name] = row_array[idx]
      end
      rows << row_hash
    end

    log_info("Query returned #{rows.size} rows")
    rows
  rescue DuckDB::Error => e
    log_error("Query failed: #{e.message}")
    raise QueryError, "DuckDB query error: #{e.message}"
  end

  # Execute SQL without returning results (for CREATE, INSERT, etc.)
  # @param sql [String] SQL statement to execute
  def execute_sql(sql)
    @connection.query(sql)
    true
  rescue DuckDB::Error => e
    log_error("SQL execution failed: #{e.message}")
    raise QueryError, "DuckDB execution error: #{e.message}"
  end

  # Get list of loaded tables
  # @return [Hash] Hash of table_name => metadata
  def loaded_tables
    @loaded_tables
  end

  # Get schema information for a table
  # @param table_name [String] Name of the table
  # @return [Array<Hash>] Array of column definitions
  def get_table_schema(table_name)
    result = query("DESCRIBE #{table_name}")
    result.map do |row|
      {
        name: row["column_name"],
        type: row["column_type"],
        null: row["null"]
      }
    end
  rescue QueryError
    []
  end

  # Close the connection and database
  def close
    @connection = nil
    @database = nil
    log_info("DuckDB connection closed")
  end

  private

  # Build CREATE TABLE SQL from sample data
  def build_create_table_sql(table_name, sample_row)
    columns_sql = sample_row.map do |key, value|
      type = infer_column_type(value)
      "#{quote_identifier(key)} #{type}"
    end.join(", ")

    "CREATE TABLE #{quote_identifier(table_name)} (#{columns_sql})"
  end

  # Infer DuckDB column type from Ruby value
  def infer_column_type(value)
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
    else
      "VARCHAR"
    end
  end

  # Insert a batch of rows into a table
  def insert_batch(table_name, columns, batch)
    values_sql = batch.map do |row|
      values = columns.map { |col| quote_value(row[col]) }.join(", ")
      "(#{values})"
    end.join(", ")

    columns_sql = columns.map { |col| quote_identifier(col) }.join(", ")
    sql = "INSERT INTO #{quote_identifier(table_name)} (#{columns_sql}) VALUES #{values_sql}"

    execute_sql(sql)
  end

  # Quote an identifier (table or column name)
  def quote_identifier(name)
    "\"#{name.to_s.gsub('"', '""')}\""
  end

  # Quote a value for SQL
  def quote_value(value)
    case value
    when nil
      "NULL"
    when Integer, Float
      value.to_s
    when TrueClass
      "TRUE"
    when FalseClass
      "FALSE"
    when Date
      "'#{value.strftime('%Y-%m-%d')}'"
    when Time, DateTime
      "'#{value.strftime('%Y-%m-%d %H:%M:%S')}'"
    else
      "'#{value.to_s.gsub("'", "''")}'"
    end
  end


  def log_info(message)
    Rails.logger.info("[DuckDbEngine] #{message}")
  end

  def log_error(message)
    Rails.logger.error("[DuckDbEngine] #{message}")
  end
end
