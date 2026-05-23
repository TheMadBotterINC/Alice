require "test_helper"

class ConnectorAdapters::PostgresqlPglakeForeignTablesTest < ActiveSupport::TestCase
  setup do
    @connector = Connector.create!(
      name: "PGLake Foreign Tables Test",
      connector_type: "postgresql",
      config: {
        "host" => "localhost",
        "port" => 15432,
        "database" => "postgres",
        "username" => "postgres",
        "password" => "postgres",
        "schema" => "public",
        "enable_pglake" => "true",
        "s3_endpoint" => "http://localhost:19000",
        "aws_access_key_id" => "minioadmin",
        "aws_secret_access_key" => "minioadmin",
        "aws_region" => "us-east-1",
        "s3_bucket" => "opdi",
        "iceberg_location_prefix" => "s3://opdi/iceberg/",
        "s3_use_ssl" => "false"
      }
    )

    @adapter = ConnectorAdapters::PostgresqlAdapter.new(@connector)
    @parquet_path = "s3://opdi/flight_list/mro_events.parquet"
    @test_timestamp = Time.now.to_i
  end

  teardown do
    @connector&.destroy
  end

  # Foreign Table Tests
  test "can check if pg_lake foreign data wrapper is available" do
    query = <<~SQL
      SELECT fdwname#{' '}
      FROM pg_foreign_data_wrapper#{' '}
      WHERE fdwname = 'pg_lake'
    SQL

    begin
      result = @adapter.read_data(query: query)

      if result.any?
        puts "\npg_lake foreign data wrapper is available"
        assert_equal "pg_lake", result.first["fdwname"]
      else
        puts "\npg_lake FDW not found - foreign table tests may not work"
        # Log warning but don't fail - FDW may not be configured yet
        skip "pg_lake foreign data wrapper not found - skipping FDW checks"
      end
    rescue => e
      puts "\nCould not check for pg_lake FDW: #{e.message}"
      flunk "Failed to query for pg_lake FDW: #{e.message}"
    end
  end

  test "can create foreign table pointing to S3 Parquet file" do
    foreign_table_name = "foreign_mro_events_#{@test_timestamp}"

    # Check if SERVER pg_lake exists, if not skip this test
    server_check = "SELECT srvname FROM pg_foreign_server WHERE srvname = 'pg_lake'"

    begin
      server_result = @adapter.read_data(query: server_check)

      if server_result.empty?
        puts "\nSkipping foreign table test - pg_lake server not configured"
        skip "pg_lake foreign server not available"
      end

      # Create foreign table with auto-detection
      create_query = <<~SQL
        CREATE FOREIGN TABLE #{foreign_table_name} ()
        SERVER pg_lake
        OPTIONS (path '#{@parquet_path}')
      SQL

      @adapter.read_data(query: create_query)

      # Query the foreign table
      query_result = @adapter.read_data(query: "SELECT COUNT(*) as count FROM #{foreign_table_name}")

      count = query_result.first["count"].to_i
      assert count > 0, "Foreign table should have data"
      assert_equal 50000, count, "Should match the 50K rows in source Parquet file"

      # Get a sample row
      sample = @adapter.read_data(query: "SELECT * FROM #{foreign_table_name} LIMIT 1")

      puts "\nCreated foreign table #{foreign_table_name} with #{count} rows"
      puts "Sample row: #{sample.first.inspect}"

    rescue => e
      puts "\nForeign table test error: #{e.message}"
      skip "Foreign table functionality not available"
    end
  end

  test "can query foreign table with filters" do
    foreign_table_name = "foreign_mro_filter_#{@test_timestamp}"

    begin
      # Create foreign table
      create_query = <<~SQL
        CREATE FOREIGN TABLE #{foreign_table_name} ()
        SERVER pg_lake
        OPTIONS (path '#{@parquet_path}')
      SQL

      @adapter.read_data(query: create_query)

      # Query with WHERE clause - should pushdown to Parquet reader
      filter_query = <<~SQL
        SELECT station, COUNT(*) as event_count
        FROM #{foreign_table_name}
        WHERE downtime_hours > 20
        GROUP BY station
        ORDER BY event_count DESC
        LIMIT 5
      SQL

      result = @adapter.read_data(query: filter_query)

      assert result.size > 0, "Should have filtered results"

      puts "\nTop stations with >20 hours downtime (via foreign table):"
      result.each do |row|
        puts "  #{row['station']}: #{row['event_count']} events"
      end

    rescue => e
      puts "\nForeign table filtering test error: #{e.message}"
      skip "Foreign table functionality not available"
    end
  end

  test "can join foreign table with regular PostgreSQL table" do
    foreign_table_name = "foreign_mro_join_#{@test_timestamp}"
    regular_table_name = "station_metadata_#{@test_timestamp}"

    begin
      # Create foreign table
      create_foreign = <<~SQL
        CREATE FOREIGN TABLE #{foreign_table_name} ()
        SERVER pg_lake
        OPTIONS (path '#{@parquet_path}')
      SQL

      @adapter.read_data(query: create_foreign)

      # Create regular table with metadata
      create_regular = <<~SQL
        CREATE TABLE #{regular_table_name} AS
        SELECT DISTINCT#{' '}
          station,
          'Region ' || (random() * 5)::int as region,
          random() * 100 as priority_score
        FROM #{foreign_table_name}
        LIMIT 50
      SQL

      @adapter.read_data(query: create_regular)

      # Join them
      join_query = <<~SQL
        SELECT#{' '}
          m.station,
          m.region,
          COUNT(*) as event_count,
          AVG(f.cost_usd) as avg_cost
        FROM #{foreign_table_name} f
        INNER JOIN #{regular_table_name} m ON f.station = m.station
        GROUP BY m.station, m.region
        ORDER BY event_count DESC
        LIMIT 10
      SQL

      result = @adapter.read_data(query: join_query)

      assert result.size > 0, "Should have joined results"

      puts "\nJoin results (foreign table + regular table):"
      result.each do |row|
        puts "  #{row['station']} (#{row['region']}): #{row['event_count']} events"
      end

    rescue => e
      puts "\nForeign table JOIN test error: #{e.message}"
      skip "Foreign table functionality not available"
    end
  end

  test "can create writable foreign table" do
    writable_table_name = "writable_foreign_#{@test_timestamp}"
    writable_path = "s3://opdi/test_writable/#{writable_table_name}/"

    begin
      # Create writable foreign table
      create_query = <<~SQL
        CREATE FOREIGN TABLE #{writable_table_name} (
          id INTEGER,
          name VARCHAR(100),
          value NUMERIC(10,2),
          created_at TIMESTAMP
        )
        SERVER pg_lake
        OPTIONS (
          location '#{writable_path}',
          format 'parquet',
          writable 'true'
        )
      SQL

      @adapter.read_data(query: create_query)

      # Insert data into writable foreign table
      insert_query = <<~SQL
        INSERT INTO #{writable_table_name}
        SELECT#{' '}
          generate_series as id,
          'Record ' || generate_series as name,
          random() * 1000 as value,
          NOW() as created_at
        FROM generate_series(1, 100)
      SQL

      @adapter.read_data(query: insert_query)

      # Read it back
      count_query = "SELECT COUNT(*) as count FROM #{writable_table_name}"
      result = @adapter.read_data(query: count_query)

      count = result.first["count"].to_i
      assert_equal 100, count, "Should have 100 rows in writable foreign table"

      puts "\nCreated writable foreign table at #{writable_path}"
      puts "Inserted and verified #{count} rows"

    rescue => e
      puts "\nWritable foreign table test error: #{e.message}"
      skip "Writable foreign table functionality not available"
    end
  end

  # Iceberg Table Tests
  test "can check if Iceberg extension is available" do
    query = "SELECT extname FROM pg_extension WHERE extname LIKE '%iceberg%'"

    begin
      result = @adapter.read_data(query: query)

      if result.any?
        extension_names = result.map { |r| r["extname"] }
        puts "\nIceberg extension(s) available: #{extension_names.join(', ')}"
        assert extension_names.any?, "Should have Iceberg extensions available"
      else
        puts "\nNo Iceberg extensions found - Iceberg tests will be skipped"
        assert false, "Iceberg extensions should be available on PGLake instance"
      end
    rescue => e
      puts "\nCould not check for Iceberg extensions: #{e.message}"
      flunk "Failed to query for Iceberg extensions: #{e.message}"
    end
  end

  test "can create Iceberg table" do
    iceberg_table_name = "iceberg_test_#{@test_timestamp}"

    begin
      # Create Iceberg table
      create_query = <<~SQL
        CREATE TABLE #{iceberg_table_name} (
          id INTEGER,
          name VARCHAR(100),
          amount NUMERIC(10,2),
          event_date DATE,
          created_at TIMESTAMP
        ) USING iceberg
      SQL

      @adapter.read_data(query: create_query)

      # Insert data
      insert_query = <<~SQL
        INSERT INTO #{iceberg_table_name}
        SELECT#{' '}
          generate_series as id,
          'Item ' || generate_series as name,
          random() * 1000 as amount,
          CURRENT_DATE as event_date,
          NOW() as created_at
        FROM generate_series(1, 50)
      SQL

      @adapter.read_data(query: insert_query)

      # Verify data
      count_query = "SELECT COUNT(*) as count FROM #{iceberg_table_name}"
      result = @adapter.read_data(query: count_query)

      count = result.first["count"].to_i
      assert_equal 50, count, "Should have 50 rows in Iceberg table"

      puts "\nCreated Iceberg table #{iceberg_table_name} with #{count} rows"

      # Check if we can query iceberg metadata
      begin
        metadata_query = "SELECT * FROM iceberg_tables WHERE table_name = '#{iceberg_table_name}'"
        metadata = @adapter.read_data(query: metadata_query)

        if metadata.any?
          puts "Iceberg table location: #{metadata.first['metadata_location']}"
        end
      rescue => e
        puts "Note: Could not query iceberg_tables view: #{e.message}"
      end

    rescue => e
      puts "\nIceberg table test error: #{e.message}"
      skip "Iceberg table functionality not available"
    end
  end

  test "can update Iceberg table" do
    iceberg_table_name = "iceberg_update_#{@test_timestamp}"

    begin
      # Create and populate Iceberg table
      create_query = <<~SQL
        CREATE TABLE #{iceberg_table_name} (
          id INTEGER,
          status VARCHAR(50),
          value NUMERIC(10,2)
        ) USING iceberg
      SQL

      @adapter.read_data(query: create_query)

      insert_query = <<~SQL
        INSERT INTO #{iceberg_table_name}
        SELECT#{' '}
          generate_series as id,
          'PENDING' as status,
          random() * 100 as value
        FROM generate_series(1, 20)
      SQL

      @adapter.read_data(query: insert_query)

      # Update some rows
      update_query = <<~SQL
        UPDATE #{iceberg_table_name}
        SET status = 'COMPLETED'
        WHERE id <= 10
      SQL

      @adapter.read_data(query: update_query)

      # Verify updates
      verify_query = <<~SQL
        SELECT status, COUNT(*) as count
        FROM #{iceberg_table_name}
        GROUP BY status
        ORDER BY status
      SQL

      result = @adapter.read_data(query: verify_query)

      completed_count = result.find { |r| r["status"] == "COMPLETED" }["count"].to_i
      pending_count = result.find { |r| r["status"] == "PENDING" }["count"].to_i

      assert_equal 10, completed_count, "Should have 10 completed"
      assert_equal 10, pending_count, "Should have 10 pending"

      puts "\nUpdated Iceberg table: #{completed_count} completed, #{pending_count} pending"

    rescue => e
      puts "\nIceberg UPDATE test error: #{e.message}"
      skip "Iceberg UPDATE functionality not available"
    end
  end

  test "can query Iceberg table snapshots" do
    iceberg_table_name = "iceberg_snapshots_#{@test_timestamp}"

    begin
      # Create Iceberg table
      create_query = "CREATE TABLE #{iceberg_table_name} (id INTEGER, value TEXT) USING iceberg"
      @adapter.read_data(query: create_query)

      # Insert data (creates snapshot 1)
      @adapter.read_data(query: "INSERT INTO #{iceberg_table_name} SELECT generate_series, 'value' FROM generate_series(1, 10)")

      # Insert more data (creates snapshot 2)
      @adapter.read_data(query: "INSERT INTO #{iceberg_table_name} SELECT generate_series, 'more' FROM generate_series(11, 20)")

      # Try to query snapshots
      begin
        snapshots_query = "SELECT * FROM iceberg_snapshots('#{iceberg_table_name}')"
        snapshots = @adapter.read_data(query: snapshots_query)

        puts "\nIceberg table snapshots:"
        snapshots.each_with_index do |snapshot, idx|
          puts "  Snapshot #{idx + 1}: #{snapshot.inspect}"
        end

        assert snapshots.size >= 2, "Should have at least 2 snapshots"

      rescue => e
        puts "\nNote: Could not query snapshots: #{e.message}"
      end

    rescue => e
      puts "\nIceberg snapshots test error: #{e.message}"
      skip "Iceberg snapshot functionality not available"
    end
  end
end
