module ConnectorAdapters
  class SnowflakeAdapter < BaseAdapter
    def read_data(query: nil)
      start_time = Time.current
      log_info("⏱️  [SnowflakeAdapter] Starting read_data at #{start_time}")
      log_info("Reading data from Snowflake")
      log_info("Query: #{query}") if query

      # Default query if none provided
      sql = query || "SELECT * FROM #{config['table_name'] || config['dataset_name']}"

      result = client.execute_query(sql)
      duration = Time.current - start_time

      log_info("⏱️  [SnowflakeAdapter] read_data completed in #{duration.round(2)}s, returned #{result.size} rows")
      result
    rescue SnowflakeClient::QueryError, SnowflakeClient::ConnectionError => e
      log_error("Failed to read data: #{e.message}")
      raise QueryError, e.message
    end

    def write_data(table_name:, data:, write_disposition: :append, schema: nil)
      # Extract schema name and merge_key from schema parameter
      if schema.is_a?(Hash)
        target_schema = schema[:schema] || config["schema"] || "PUBLIC"
        merge_key = schema[:merge_key]
      else
        target_schema = schema || config["schema"] || "PUBLIC"
        merge_key = nil
      end

      log_info("Writing #{data.size} rows to Snowflake table '#{target_schema}.#{table_name}' with disposition '#{write_disposition}'")

      return { rows_affected: 0, message: "No data to write" } if data.empty?

      # Handle write disposition
      case write_disposition.to_sym
      when :truncate_and_load
        truncate_table(table_name, schema: target_schema)
        # Insert data in batches
        rows_inserted = batch_insert(table_name, data, schema: target_schema)
      when :merge
        # Merge requires a merge_key parameter
        raise ArgumentError, "merge_key is required for merge write disposition" if merge_key.blank?

        # Perform merge operation
        rows_inserted = merge_data(table_name, data, merge_key: merge_key, schema: target_schema)
      else
        # Append (default): just insert
        rows_inserted = batch_insert(table_name, data, schema: target_schema)
      end

      {
        rows_affected: rows_inserted,
        table_name: table_name,
        schema: target_schema,
        write_disposition: write_disposition,
        message: "Successfully wrote #{rows_inserted} rows to Snowflake"
      }
    rescue SnowflakeClient::QueryError, SnowflakeClient::ConnectionError => e
      log_error("Failed to write data: #{e.message}")
      raise QueryError, e.message
    end

    def test_connection
      log_info("Testing Snowflake connection")

      # Basic connection test
      result = client.test_connection
      log_info("Connection test #{result ? 'successful' : 'failed'}")

      if result
        # Fetch and log available schemas and tables as preview
        begin
          log_info("Fetching available schemas and tables...")
          preview = get_database_preview
          log_info("Database preview: #{preview.to_json}")
        rescue => e
          log_error("Failed to fetch database preview: #{e.message}")
        end
      end

      result
    rescue => e
      log_error("Connection test failed: #{e.message}")
      false
    end

    def get_schema(table_name: nil)
      log_info("Getting schema for table '#{table_name}'")

      table = table_name || config["table_name"] || config["dataset_name"]
      raise ArgumentError, "Table name required" unless table

      client.describe_table(table)
    rescue SnowflakeClient::QueryError => e
      log_error("Failed to get schema: #{e.message}")
      raise QueryError, e.message
    end

    # Get detailed schema information for a specific table
    def get_table_schema(schema_name:, table_name:)
      log_info("Getting schema for #{schema_name}.#{table_name}")

      sql = <<~SQL
        SELECT#{' '}
          COLUMN_NAME,
          DATA_TYPE,
          IS_NULLABLE,
          COLUMN_DEFAULT,
          CHARACTER_MAXIMUM_LENGTH,
          NUMERIC_PRECISION,
          NUMERIC_SCALE
        FROM #{config['database']}.INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = '#{schema_name}'
          AND TABLE_NAME = '#{table_name}'
        ORDER BY ORDINAL_POSITION
      SQL

      columns = client.execute_query(sql)

      {
        database: config["database"],
        schema: schema_name,
        table: table_name,
        columns: columns.map do |col|
          {
            name: col["COLUMN_NAME"],
            type: col["DATA_TYPE"],
            nullable: col["IS_NULLABLE"] == "YES",
            default: col["COLUMN_DEFAULT"],
            max_length: col["CHARACTER_MAXIMUM_LENGTH"],
            precision: col["NUMERIC_PRECISION"],
            scale: col["NUMERIC_SCALE"]
          }
        end
      }
    rescue => e
      log_error("Failed to get table schema: #{e.message}")
      raise QueryError, e.message
    end

    # Get a preview of available schemas and tables
    def get_database_preview
      start_time = Time.current
      log_info("⏱️  [SnowflakeAdapter] Starting get_database_preview")

      # Query to get all schemas in the database (excluding system schemas)
      schemas_sql = """
        SELECT SCHEMA_NAME
        FROM #{config['database']}.INFORMATION_SCHEMA.SCHEMATA
        WHERE SCHEMA_NAME != 'INFORMATION_SCHEMA'
        ORDER BY SCHEMA_NAME
      """

      schemas_start = Time.current
      schemas = client.execute_query(schemas_sql)
      log_info("⏱️  [SnowflakeAdapter] Fetched #{schemas.size} schemas in #{(Time.current - schemas_start).round(2)}s")

      preview = schemas.first(10).map do |schema_row|
        schema_name = schema_row["SCHEMA_NAME"]

        # Query to get tables in this schema
        tables_sql = """
          SELECT TABLE_NAME, TABLE_TYPE, ROW_COUNT
          FROM #{config['database']}.INFORMATION_SCHEMA.TABLES
          WHERE TABLE_SCHEMA = '#{schema_name}'
          ORDER BY TABLE_NAME
          LIMIT 20
        """

        begin
          tables = client.execute_query(tables_sql)
          {
            schema: schema_name,
            table_count: tables.size,
            tables: tables.map { |t| { name: t["TABLE_NAME"], type: t["TABLE_TYPE"], rows: t["ROW_COUNT"] } }
          }
        rescue => e
          log_error("Failed to fetch tables for schema #{schema_name}: #{e.message}")
          {
            schema: schema_name,
            table_count: 0,
            tables: [],
            error: e.message
          }
        end
      end

      {
        database: config["database"],
        total_schemas: schemas.size,
        schemas_preview: preview
      }
    end

    # Close the Snowflake client connection
    def close
      if @client
        log_info("Closing Snowflake client connection")
        @client.close
        @client = nil
      end
    end

    protected

    def validate_config!
      super

      required_keys = %w[account username database warehouse private_key]
      missing = required_keys - config.keys

      if missing.any?
        raise ConnectionError, "Missing required Snowflake config: #{missing.join(', ')}"
      end

      # Validate private_key is not blank
      if config["private_key"].blank?
        raise ConnectionError, "Private key is required for Snowflake authentication"
      end
    end

    private

    # Get configuration hash with string keys
    def config
      @config ||= connector.config.with_indifferent_access
    end

    # Lazy initialize Snowflake client
    def client
      @client ||= SnowflakeClient.new(
        account: config["account"],
        username: config["username"],
        private_key: config["private_key"],
        database: config["database"],
        warehouse: config["warehouse"],
        schema: config["schema"] || "PUBLIC",
        role: config["role"]
      )
    end

    # Truncate a table
    def truncate_table(table_name, schema: nil)
      target_schema = schema || config["schema"] || "PUBLIC"
      sql = "TRUNCATE TABLE IF EXISTS #{config['database']}.#{target_schema}.#{table_name}"
      client.execute_query(sql)
      log_info("Truncated table #{target_schema}.#{table_name}")
    end

    # Batch insert data into Snowflake
    def batch_insert(table_name, data, schema: nil)
      return 0 if data.empty?

      target_schema = schema || config["schema"] || "PUBLIC"

      # Get column names from first row
      columns = data.first.keys
      batch_size = 1000
      total_inserted = 0

      data.each_slice(batch_size) do |batch|
        values_clauses = batch.map do |row|
          values = columns.map { |col| quote_value(row[col]) }
          "(#{values.join(', ')})"
        end

        sql = <<~SQL
          INSERT INTO #{config['database']}.#{target_schema}.#{table_name}
          (#{columns.join(', ')})
          VALUES #{values_clauses.join(", ")}
        SQL

        client.execute_query(sql)
        total_inserted += batch.size
        log_info("Inserted batch of #{batch.size} rows (#{total_inserted}/#{data.size})")
      end

      total_inserted
    end

    # Merge data using staging table and MERGE statement
    def merge_data(table_name, data, merge_key:, schema: nil)
      return 0 if data.empty?
      raise ArgumentError, "merge_key is required for merge operation" if merge_key.blank?

      target_schema = schema || config["schema"] || "PUBLIC"
      staging_table = "#{table_name}_STAGING_#{Time.current.to_i}"
      merge_keys = merge_key.split(",").map(&:strip)

      log_info("Starting merge operation with merge_key: #{merge_keys.join(', ')}")

      begin
        # Step 1: Create staging table (temporary)
        columns = data.first.keys
        create_staging_table(staging_table, columns, schema: target_schema)

        # Step 2: Insert data into staging table
        rows_staged = batch_insert(staging_table, data, schema: target_schema)
        log_info("Staged #{rows_staged} rows in temporary table")

        # Step 3: Execute MERGE statement
        merge_result = execute_merge(table_name, staging_table, columns, merge_keys, schema: target_schema)
        log_info("Merge complete: #{merge_result[:updated]} updated, #{merge_result[:inserted]} inserted")

        # Return total rows affected
        merge_result[:updated] + merge_result[:inserted]
      ensure
        # Step 4: Drop staging table
        drop_staging_table(staging_table, schema: target_schema)
      end
    end

    # Create a staging table with the same structure as target
    def create_staging_table(table_name, columns, schema: nil)
      target_schema = schema || config["schema"] || "PUBLIC"

      # Create table with VARCHAR columns (simple approach)
      column_defs = columns.map { |col| "#{col} VARCHAR" }.join(", ")

      sql = <<~SQL
        CREATE TEMPORARY TABLE #{config['database']}.#{target_schema}.#{table_name}
        (#{column_defs})
      SQL

      client.execute_query(sql)
      log_info("Created staging table #{target_schema}.#{table_name}")
    end

    # Drop staging table
    def drop_staging_table(table_name, schema: nil)
      target_schema = schema || config["schema"] || "PUBLIC"

      sql = "DROP TABLE IF EXISTS #{config['database']}.#{target_schema}.#{table_name}"
      client.execute_query(sql)
      log_info("Dropped staging table #{target_schema}.#{table_name}")
    rescue => e
      log_error("Failed to drop staging table: #{e.message}")
      # Don't fail the merge if we can't drop staging table
    end

    # Execute MERGE statement
    def execute_merge(target_table, staging_table, columns, merge_keys, schema: nil)
      target_schema = schema || config["schema"] || "PUBLIC"
      full_target = "#{config['database']}.#{target_schema}.#{target_table}"
      full_staging = "#{config['database']}.#{target_schema}.#{staging_table}"

      # Build ON clause for merge keys
      on_conditions = merge_keys.map { |key| "target.#{key} = source.#{key}" }.join(" AND ")

      # Build UPDATE SET clause (all columns except merge keys)
      update_columns = columns - merge_keys
      update_set = update_columns.map { |col| "target.#{col} = source.#{col}" }.join(", ")

      # Build INSERT clause
      insert_columns = columns.join(", ")
      insert_values = columns.map { |col| "source.#{col}" }.join(", ")

      sql = <<~SQL
        MERGE INTO #{full_target} AS target
        USING #{full_staging} AS source
        ON #{on_conditions}
        WHEN MATCHED THEN
          UPDATE SET #{update_set}
        WHEN NOT MATCHED THEN
          INSERT (#{insert_columns})
          VALUES (#{insert_values})
      SQL

      log_info("Executing MERGE statement")
      result = client.execute_query(sql)

      # Snowflake MERGE returns row counts
      # Parse result to get inserted/updated counts
      {
        updated: result.dig(0, "number of rows updated") || 0,
        inserted: result.dig(0, "number of rows inserted") || 0
      }
    end

    # Quote SQL values for insertion
    def quote_value(value)
      case value
      when nil
        "NULL"
      when String
        "'#{value.gsub("'", "''")}'" # Escape single quotes
      when TrueClass, FalseClass
        value.to_s.upcase
      when Numeric
        value.to_s
      when Time, DateTime, Date
        "'#{value.iso8601}'"
      else
        "'#{value.to_s.gsub("'", "''")}'"
      end
    end
  end
end
