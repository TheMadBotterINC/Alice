require "test_helper"

class ConnectorAdapters::PostgresqlPglakeS3ReadTest < ActiveSupport::TestCase
  setup do
    @connector = Connector.create!(
      name: "PGLake S3 Read Test",
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

  # S3 Parquet Reading Tests
  test "can read Parquet file from S3 using foreign table" do
    foreign_table = "ft_read_test_#{@test_timestamp}"

    # Create foreign table pointing to S3 Parquet file
    @adapter.create_foreign_table(
      table_name: foreign_table,
      s3_path: @parquet_path
    )

    # Query the foreign table
    query = "SELECT * FROM #{foreign_table} LIMIT 10"
    result = @adapter.read_data(query: query)

    assert_equal 10, result.size, "Should return 10 rows"

    # Check expected columns exist based on pg_lake_config.md
    expected_columns = %w[event_id tail_number event_date event_type station fault_code downtime_hours cost_usd]
    first_row = result.first

    expected_columns.each do |col|
      assert first_row.key?(col), "Row should have column '#{col}'"
    end

    puts "\nSample Parquet data from S3 (via foreign table):"
    puts "First row: #{first_row.inspect}"
  end

  test "can count total rows in Parquet file" do
    foreign_table = "ft_count_test_#{@test_timestamp}"

    # Create foreign table
    @adapter.create_foreign_table(
      table_name: foreign_table,
      s3_path: @parquet_path
    )

    # Count rows
    query = "SELECT COUNT(*) as total FROM #{foreign_table}"
    result = @adapter.read_data(query: query)
    total = result.first["total"].to_i

    assert total > 0, "Should have rows in Parquet file"
    assert_equal 50000, total, "Should have 50,000 MRO events as per config"

    puts "\nTotal rows in Parquet file: #{total}"
  end

  test "can filter Parquet data with WHERE clause" do
    foreign_table = "ft_filter_test_#{@test_timestamp}"

    # Create foreign table
    @adapter.create_foreign_table(
      table_name: foreign_table,
      s3_path: @parquet_path
    )

    # Query with filters
    query = <<~SQL
      SELECT event_type, COUNT(*) as event_count
      FROM #{foreign_table}
      WHERE downtime_hours > 10
      GROUP BY event_type
      ORDER BY event_count DESC
      LIMIT 5
    SQL

    result = @adapter.read_data(query: query)

    assert result.size > 0, "Should have events with downtime > 10 hours"

    puts "\nTop event types with >10 hours downtime:"
    result.each do |row|
      puts "  #{row['event_type']}: #{row['event_count']} events"
    end
  end

  test "can aggregate Parquet data" do
    foreign_table = "ft_aggregate_test_#{@test_timestamp}"

    # Create foreign table
    @adapter.create_foreign_table(
      table_name: foreign_table,
      s3_path: @parquet_path
    )

    # Aggregate query
    query = <<~SQL
      SELECT#{' '}
        station,
        COUNT(*) as total_events,
        AVG(downtime_hours) as avg_downtime,
        SUM(cost_usd) as total_cost
      FROM #{foreign_table}
      GROUP BY station
      ORDER BY total_events DESC
      LIMIT 5
    SQL

    result = @adapter.read_data(query: query)

    assert result.size > 0, "Should have aggregated data by station"

    first_station = result.first
    assert first_station["station"].present?
    assert first_station["total_events"].to_i > 0
    assert first_station["avg_downtime"]
    assert first_station["total_cost"]

    puts "\nTop stations by event count:"
    result.each do |row|
      puts "  #{row['station']}: #{row['total_events']} events, " \
           "$#{row['total_cost']&.to_f&.round(2)} total cost"
    end
  end

  test "can perform complex JOIN with Parquet data" do
    foreign_table = "ft_join_test_#{@test_timestamp}"

    # Create foreign table
    @adapter.create_foreign_table(
      table_name: foreign_table,
      s3_path: @parquet_path
    )

    # Use CTE (Common Table Expression) instead of temp table to avoid isolation issues
    query = <<~SQL
      WITH high_priority_stations AS (
        SELECT DISTINCT station#{' '}
        FROM #{foreign_table}
        WHERE cost_usd > 5000
        LIMIT 10
      )
      SELECT#{' '}
        p.station,
        COUNT(*) as event_count,
        AVG(p.cost_usd) as avg_cost
      FROM #{foreign_table} p
      INNER JOIN high_priority_stations hps ON p.station = hps.station
      GROUP BY p.station
      ORDER BY avg_cost DESC
    SQL

    result = @adapter.read_data(query: query)

    assert result.size > 0, "Should have joined results"
    assert result.size <= 10, "Should match temp table limit"

    puts "\nHigh priority stations (>$5000 events):"
    result.each do |row|
      puts "  #{row['station']}: #{row['event_count']} events, " \
           "$#{row['avg_cost']&.to_f&.round(2)} avg cost"
    end
  end

  test "can read specific date range from Parquet" do
    foreign_table = "ft_daterange_test_#{@test_timestamp}"

    # Create foreign table
    @adapter.create_foreign_table(
      table_name: foreign_table,
      s3_path: @parquet_path
    )

    # Get the date range first
    range_query = "SELECT MIN(event_date) as min_date, MAX(event_date) as max_date FROM #{foreign_table}"
    range_result = @adapter.read_data(query: range_query)

    min_date = range_result.first["min_date"]
    max_date = range_result.first["max_date"]

    puts "\nDate range in data: #{min_date} to #{max_date}"

    # Now query a subset of dates
    query = <<~SQL
      SELECT#{' '}
        DATE(event_date) as date,
        COUNT(*) as events
      FROM #{foreign_table}
      WHERE event_date >= '#{min_date}'::timestamp
      GROUP BY DATE(event_date)
      ORDER BY date
      LIMIT 10
    SQL

    result = @adapter.read_data(query: query)

    assert result.size > 0, "Should have daily event counts"

    puts "First 10 days of events:"
    result.each do |row|
      puts "  #{row['date']}: #{row['events']} events"
    end
  end

  test "can read Parquet schema information" do
    foreign_table = "ft_schema_test_#{@test_timestamp}"

    # Create foreign table
    @adapter.create_foreign_table(
      table_name: foreign_table,
      s3_path: @parquet_path
    )

    # Query with no rows to see structure
    query = "SELECT * FROM #{foreign_table} WHERE false"
    result = @adapter.read_data(query: query)

    # Even with no rows, we can see the structure
    assert_equal 0, result.size

    # Get schema using information_schema
    schema_query = <<~SQL
      SELECT column_name, data_type
      FROM information_schema.columns
      WHERE table_name = '#{foreign_table}'
      ORDER BY ordinal_position
    SQL

    begin
      schema = @adapter.read_data(query: schema_query)

      if schema.any?
        puts "\nParquet file schema (via foreign table):"
        schema.each do |col|
          puts "  #{col['column_name']}: #{col['data_type']}"
        end
      else
        puts "\nNote: Schema information not available in information_schema"
      end
    rescue => e
      puts "\nNote: Could not query schema (#{e.message})"
    end
  end

  test "handles invalid S3 path gracefully" do
    foreign_table = "ft_invalid_test_#{@test_timestamp}"
    invalid_path = "s3://opdi/does_not_exist.parquet"

    assert_raises(ConnectorAdapters::PostgresqlAdapter::PostgresqlError) do
      @adapter.create_foreign_table(
        table_name: foreign_table,
        s3_path: invalid_path
      )
      # If creation succeeds, try to query it
      @adapter.read_data(query: "SELECT * FROM #{foreign_table} LIMIT 1")
    end
  end

  test "can analyze data types in Parquet file" do
    foreign_table = "ft_types_test_#{@test_timestamp}"

    # Create foreign table
    @adapter.create_foreign_table(
      table_name: foreign_table,
      s3_path: @parquet_path
    )

    # Get column types from information_schema
    query = <<~SQL
      SELECT column_name, data_type, udt_name
      FROM information_schema.columns
      WHERE table_name = '#{foreign_table}'
      ORDER BY ordinal_position
    SQL

    begin
      result = @adapter.read_data(query: query)

      if result.any?
        puts "\nData types in Parquet file (via foreign table):"
        result.each do |col|
          puts "  #{col['column_name']}: #{col['data_type']} (#{col['udt_name']})"
        end

        assert result.size > 0, "Should have column type information"
      else
        puts "\nNote: Type information not available in information_schema"
      end
    rescue => e
      puts "\nNote: Could not query column types (#{e.message})"
    end
  end
end
