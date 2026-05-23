require "pg"

module ConnectorAdapters
  class PostgresqlAdapter < BaseAdapter
    class PostgresqlError < AdapterError; end

    attr_reader :connection

    def initialize(connector)
      super(connector)
      @connection = nil
    end

    # Test the PostgreSQL connection
    # @return [Boolean] true if connection is successful
    def test_connection
      connect
      result = connection.exec("SELECT 1 AS test")
      result.first["test"] == "1"
    rescue PG::Error => e
      log_error("Connection test failed: #{e.message}")
      false
    ensure
      disconnect
    end

    # Read data from PostgreSQL
    # @param query [String] SQL query to execute
    # @return [Array<Hash>] Array of row hashes
    def read_data(query: nil)
      raise ArgumentError, "Query is required for PostgreSQL adapter" if query.blank?

      log_info("Executing query: #{query.truncate(200)}")

      connect
      result = connection.exec(query)

      rows = result.map { |row| row.to_h }
      log_info("Query returned #{rows.size} rows")

      rows
    rescue PG::Error => e
      log_error("Query execution failed: #{e.message}")
      raise QueryError, "PostgreSQL query failed: #{e.message}"
    ensure
      disconnect
    end

    # Write data to PostgreSQL
    # @param table_name [String] Name of the table to write to
    # @param data [Array<Hash>] Array of row hashes to write
    # @param write_disposition [Symbol] :append, :truncate_and_load, or :merge
    # @return [Hash] Result with :rows_affected
    def write_data(table_name:, data:, write_disposition: :append)
      return { rows_affected: 0 } if data.empty?

      log_info("Writing #{data.size} rows to table '#{table_name}' with disposition #{write_disposition}")

      connect

      # Handle write disposition
      case write_disposition.to_sym
      when :truncate_and_load
        truncate_table(table_name)
      when :merge
        raise NotImplementedError, "Merge write disposition not yet implemented for PostgreSQL"
      end

      # Insert data
      rows_affected = insert_data(table_name, data)

      log_info("Successfully wrote #{rows_affected} rows")
      { rows_affected: rows_affected }
    rescue PG::Error => e
      log_error("Write operation failed: #{e.message}")
      raise PostgresqlError, "Failed to write data to PostgreSQL: #{e.message}"
    ensure
      disconnect
    end

    # Get the schema for a table
    # @param table_name [String] Name of the table
    # @return [Array<Hash>] Array of column definitions with :name and :type
    def get_schema(table_name: nil)
      raise ArgumentError, "Table name is required" if table_name.blank?

      log_info("Fetching schema for table '#{table_name}'")

      connect

      # Query the information_schema to get column information
      schema_name = connector.config["schema"] || "public"
      query = <<~SQL
        SELECT#{' '}
          column_name,
          data_type,
          character_maximum_length,
          is_nullable
        FROM information_schema.columns
        WHERE table_schema = $1
          AND table_name = $2
        ORDER BY ordinal_position
      SQL

      result = connection.exec_params(query, [ schema_name, table_name ])

      columns = result.map do |row|
        {
          name: row["column_name"],
          type: format_column_type(row),
          nullable: row["is_nullable"] == "YES"
        }
      end

      log_info("Found #{columns.size} columns in table '#{table_name}'")
      columns
    rescue PG::Error => e
      log_error("Failed to get schema: #{e.message}")
      raise PostgresqlError, "Failed to get schema for table '#{table_name}': #{e.message}"
    ensure
      disconnect
    end

    # Get detailed schema information for a specific table
    # @param schema_name [String] Name of the schema
    # @param table_name [String] Name of the table
    # @return [Hash] Schema information with columns array
    def get_table_schema(schema_name:, table_name:)
      log_info("Getting schema for #{schema_name}.#{table_name}")

      connect

      query = <<~SQL
        SELECT#{' '}
          column_name,
          data_type,
          character_maximum_length,
          numeric_precision,
          numeric_scale,
          is_nullable,
          column_default
        FROM information_schema.columns
        WHERE table_schema = $1
          AND table_name = $2
        ORDER BY ordinal_position
      SQL

      result = connection.exec_params(query, [ schema_name, table_name ])

      {
        database: connector.config["database"],
        schema: schema_name,
        table: table_name,
        columns: result.map do |col|
          {
            name: col["column_name"],
            type: col["data_type"],
            nullable: col["is_nullable"] == "YES",
            default: col["column_default"],
            max_length: col["character_maximum_length"],
            precision: col["numeric_precision"],
            scale: col["numeric_scale"]
          }
        end
      }
    rescue PG::Error => e
      log_error("Failed to get table schema: #{e.message}")
      raise PostgresqlError, "Failed to get table schema: #{e.message}"
    ensure
      disconnect
    end

    # List all tables in the database
    # @return [Array<String>] Array of table names
    def list_tables
      connect

      schema_name = connector.config["schema"] || "public"
      query = <<~SQL
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = $1
          AND table_type = 'BASE TABLE'
        ORDER BY table_name
      SQL

      result = connection.exec_params(query, [ schema_name ])
      tables = result.map { |row| row["table_name"] }

      log_info("Found #{tables.size} tables in schema '#{schema_name}'")
      tables
    rescue PG::Error => e
      log_error("Failed to list tables: #{e.message}")
      []
    ensure
      disconnect
    end

    protected

    def validate_config!
      super

      required_keys = %w[host database username]
      missing_keys = required_keys - connector.config.keys

      if missing_keys.any?
        raise ConnectionError, "Missing required config keys: #{missing_keys.join(', ')}"
      end
    end

    private

    # Establish connection to PostgreSQL
    def connect
      return if @connection && !@connection.finished?

      config = connector.config

      @connection = PG.connect(
        host: config["host"],
        port: config["port"] || 5432,
        dbname: config["database"],
        user: config["username"],
        password: config["password"],
        connect_timeout: 10
      )

      # Set search path if schema is specified
      if config["schema"].present?
        @connection.exec("SET search_path TO #{sanitize_identifier(config['schema'])}")
      end

      # Configure PGLake session settings if enabled
      setup_pglake_session if pglake_enabled?

      log_info("Connected to PostgreSQL at #{config['host']}:#{config['port'] || 5432}")
    rescue PG::Error => e
      log_error("Failed to connect: #{e.message}")
      raise ConnectionError, "Failed to connect to PostgreSQL: #{e.message}"
    end

    # Disconnect from PostgreSQL
    def disconnect
      return unless @connection && !@connection.finished?

      @connection.close
      @connection = nil
      log_info("Disconnected from PostgreSQL")
    rescue PG::Error => e
      log_error("Error during disconnect: #{e.message}")
    end

    # Truncate a table
    def truncate_table(table_name)
      log_info("Truncating table '#{table_name}'")
      connection.exec("TRUNCATE TABLE #{sanitize_identifier(table_name)}")
    end

    # Insert data into a table
    # @param table_name [String] Name of the table
    # @param data [Array<Hash>] Array of row hashes
    # @return [Integer] Number of rows inserted
    def insert_data(table_name, data)
      return 0 if data.empty?

      columns = data.first.keys
      column_names = columns.map { |col| sanitize_identifier(col) }.join(", ")

      # Build parameterized insert statement
      rows_inserted = 0

      # Insert in batches for better performance
      batch_size = 100
      data.each_slice(batch_size) do |batch|
        # Build multi-row insert
        values_clauses = []
        params = []
        param_index = 1

        batch.each do |row|
          placeholders = columns.map do |col|
            params << row[col]
            "$#{param_index}".tap { param_index += 1 }
          end
          values_clauses << "(#{placeholders.join(', ')})"
        end

        insert_sql = "INSERT INTO #{sanitize_identifier(table_name)} (#{column_names}) VALUES #{values_clauses.join(', ')}"
        connection.exec_params(insert_sql, params)
        rows_inserted += batch.size
      end

      rows_inserted
    end

    # Sanitize SQL identifiers (table names, column names)
    def sanitize_identifier(identifier)
      # Quote identifier to prevent SQL injection
      connection.quote_ident(identifier.to_s)
    end

    public

    # PGLake-specific helper methods (public for use in tests and pipelines)

    # Check if PGLake features are enabled for this connector
    # @return [Boolean] true if PGLake is enabled
    def pglake_enabled?
      connector.config["enable_pglake"].to_s == "true"
    end

    # Check if Iceberg is configured for this connector
    # @return [Boolean] true if Iceberg location prefix is configured
    def iceberg_configured?
      pglake_enabled? && connector.config["iceberg_location_prefix"].present?
    end

    # Configure PGLake session settings
    # This is called automatically when connecting if PGLake is enabled
    # Sets per-session configuration for S3 access and Iceberg location
    def setup_pglake_session
      config = connector.config

      begin
        # Set Iceberg location prefix for this session
        if config["iceberg_location_prefix"].present?
          location = config["iceberg_location_prefix"]
          @connection.exec("SET pg_lake_iceberg.default_location_prefix TO '#{location}'")
          log_info("Set Iceberg location prefix to #{location}")
        end

        # Set custom S3 endpoint (for MinIO, etc.)
        if config["s3_endpoint"].present?
          endpoint = config["s3_endpoint"]
          @connection.exec("SET pg_lake.s3_endpoint TO '#{endpoint}'")
          log_info("Set S3 endpoint to #{endpoint}")
        end

        # Set S3 SSL setting
        if config["s3_use_ssl"] == "false"
          @connection.exec("SET pg_lake.s3_use_ssl TO 'false'")
          log_info("Disabled S3 SSL")
        end

        # Set AWS credentials if provided
        if config["aws_access_key_id"].present?
          @connection.exec("SET pg_lake.s3_access_key_id TO '#{config['aws_access_key_id']}'")
          log_info("Set S3 access key ID")
        end

        if config["aws_secret_access_key"].present?
          @connection.exec("SET pg_lake.s3_secret_access_key TO '#{config['aws_secret_access_key']}'")
          log_info("Set S3 secret access key")
        end

        if config["aws_region"].present?
          @connection.exec("SET pg_lake.s3_region TO '#{config['aws_region']}'")
          log_info("Set S3 region to #{config['aws_region']}")
        end

        if config["s3_bucket"].present?
          @connection.exec("SET pg_lake.s3_default_bucket TO '#{config['s3_bucket']}'")
          log_info("Set S3 default bucket to #{config['s3_bucket']}")
        end

      rescue PG::Error => e
        # Log but don't fail - some PGLake versions may not support all settings
        log_info("Note: Some PGLake settings could not be applied: #{e.message}")
      end
    end

    # Create a foreign table pointing to an S3 file
    # This is the PGLake approach (not DuckDB's read_parquet)
    # @param table_name [String] Name for the foreign table
    # @param s3_path [String] S3 path (e.g., 's3://bucket/path/file.parquet')
    # @param options [Hash] Additional OPTIONS for the foreign table
    # @return [Boolean] true if successful
    def create_foreign_table(table_name:, s3_path:, options: {})
      raise ArgumentError, "PGLake is not enabled" unless pglake_enabled?

      log_info("Creating foreign table #{table_name} for #{s3_path}")

      connect

      # Build OPTIONS clause
      opts_array = [ [ "path", s3_path ] ]
      options.each do |key, value|
        opts_array << [ key.to_s, value.to_s ]
      end
      options_clause = opts_array.map { |k, v| "#{k} '#{v}'" }.join(", ")

      query = <<~SQL
        CREATE FOREIGN TABLE #{sanitize_identifier(table_name)} ()
        SERVER pg_lake
        OPTIONS (#{options_clause})
      SQL

      @connection.exec(query)
      log_info("Created foreign table #{table_name}")
      true
    rescue PG::Error => e
      log_error("Failed to create foreign table: #{e.message}")
      raise PostgresqlError, "Failed to create foreign table: #{e.message}"
    ensure
      disconnect
    end

    # Create a writable foreign table for writing to S3
    # @param table_name [String] Name for the foreign table
    # @param s3_location [String] S3 location (directory path, e.g., 's3://bucket/path/')
    # @param columns [Array<Hash>] Column definitions with :name and :type
    # @param options [Hash] Additional OPTIONS
    # @return [Boolean] true if successful
    def create_writable_foreign_table(table_name:, s3_location:, columns:, options: {})
      raise ArgumentError, "PGLake is not enabled" unless pglake_enabled?
      raise ArgumentError, "Columns must be provided" if columns.empty?

      log_info("Creating writable foreign table #{table_name} at #{s3_location}")

      connect

      # Build column definitions
      column_defs = columns.map do |col|
        "#{sanitize_identifier(col[:name])} #{col[:type]}"
      end.join(", ")

      # Build OPTIONS clause
      opts = { "location" => s3_location, "writable" => "true" }.merge(options)
      options_clause = opts.map { |k, v| "#{k} '#{v}'" }.join(", ")

      query = <<~SQL
        CREATE FOREIGN TABLE #{sanitize_identifier(table_name)} (
          #{column_defs}
        )
        SERVER pg_lake
        OPTIONS (#{options_clause})
      SQL

      @connection.exec(query)
      log_info("Created writable foreign table #{table_name}")
      true
    rescue PG::Error => e
      log_error("Failed to create writable foreign table: #{e.message}")
      raise PostgresqlError, "Failed to create writable foreign table: #{e.message}"
    ensure
      disconnect
    end

    private

    # Format column type with length information
    def format_column_type(column_info)
      type = column_info["data_type"]
      max_length = column_info["character_maximum_length"]

      if max_length && %w[character varchar].include?(type)
        "#{type}(#{max_length})"
      else
        type
      end
    end
  end
end
