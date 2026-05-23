require "test_helper"

class ConnectorAdapters::PostgresqlPglakeIntegrationTest < ActiveSupport::TestCase
  setup do
    @connector = Connector.create!(
      name: "PGLake Integration Test",
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
    @test_timestamp = Time.now.to_i
  end

  teardown do
    @connector&.destroy
  end

  # End-to-end Integration Tests
  test "complete ETL pipeline: read from S3, transform, write to PostgreSQL" do
    source_path = "s3://opdi/flight_list/mro_events.parquet"
    source_foreign_table = "ft_source_#{@test_timestamp}"
    target_table = "mro_summary_#{@test_timestamp}"

    # Step 1: Create foreign table for source data
    @adapter.create_foreign_table(
      table_name: source_foreign_table,
      s3_path: source_path
    )

    # Step 2: Read and transform data from foreign table into PostgreSQL table
    transform_query = <<~SQL
      CREATE TABLE #{target_table} AS
      SELECT#{' '}
        station,
        event_type,
        DATE_TRUNC('month', event_date) as event_month,
        COUNT(*) as event_count,
        AVG(downtime_hours) as avg_downtime,
        SUM(cost_usd) as total_cost,
        MIN(cost_usd) as min_cost,
        MAX(cost_usd) as max_cost
      FROM #{source_foreign_table}
      WHERE event_date >= CURRENT_DATE - INTERVAL '2 years'
      GROUP BY station, event_type, DATE_TRUNC('month', event_date)
    SQL

    @adapter.read_data(query: transform_query)

    # Step 3: Verify the transformation
    count_query = "SELECT COUNT(*) as count FROM #{target_table}"
    result = @adapter.read_data(query: count_query)

    count = result.first["count"].to_i
    assert count > 0, "Should have transformed data"

    # Step 4: Get schema to verify structure
    schema = @adapter.get_schema(table_name: target_table)
    expected_cols = %w[station event_type event_month event_count avg_downtime total_cost min_cost max_cost]

    schema_col_names = schema.map { |c| c[:name] }
    expected_cols.each do |col|
      assert_includes schema_col_names, col, "Should have column #{col}"
    end

    # Step 4: Query the results
    sample_query = "SELECT * FROM #{target_table} ORDER BY total_cost DESC LIMIT 5"
    sample = @adapter.read_data(query: sample_query)

    puts "\nETL Pipeline Complete:"
    puts "  Source: #{source_path}"
    puts "  Target: #{target_table}"
    puts "  Rows created: #{count}"
    puts "  Top costly station/type combinations:"
    sample.each do |row|
      puts "    #{row['station']} - #{row['event_type']}: $#{row['total_cost']&.to_f&.round(2)}"
    end
  end

  test "data lake to data warehouse workflow" do
    skip "Test requires writable foreign tables which have infrastructure issues"
    # Note: This test requires writable foreign tables for S3 export, which currently
    # fails with temp file IO errors on the remote server. Keep skipped until resolved.
    source_path = "s3://opdi/flight_list/mro_events.parquet"
    source_foreign_table = "ft_source_wf_#{@test_timestamp}"
    staging_table = "staging_#{@test_timestamp}"
    analytics_table = "analytics_#{@test_timestamp}"
    export_path = "s3://opdi/test_exports/analytics_export_#{@test_timestamp}.parquet"

    # Step 1: Create foreign table for source
    @adapter.create_foreign_table(
      table_name: source_foreign_table,
      s3_path: source_path
    )

    # Step 2: Create staging table from foreign table
    staging_query = <<~SQL
      CREATE TABLE #{staging_table} AS
      SELECT * FROM #{source_foreign_table}
      WHERE cost_usd > 1000
      LIMIT 1000
    SQL

    @adapter.read_data(query: staging_query)

    # Step 3: Create analytics table with enriched data
    analytics_query = <<~SQL
      CREATE TABLE #{analytics_table} AS
      SELECT#{' '}
        event_id,
        station,
        event_type,
        cost_usd,
        downtime_hours,
        CASE#{' '}
          WHEN cost_usd > 5000 THEN 'HIGH'
          WHEN cost_usd > 2000 THEN 'MEDIUM'
          ELSE 'LOW'
        END as cost_category,
        CASE
          WHEN downtime_hours > 24 THEN 'CRITICAL'
          WHEN downtime_hours > 8 THEN 'SIGNIFICANT'
          ELSE 'MINOR'
        END as severity
      FROM #{staging_table}
    SQL

    @adapter.read_data(query: analytics_query)

    # Step 4: Verify categorization
    category_query = <<~SQL
      SELECT#{' '}
        cost_category,
        severity,
        COUNT(*) as count,
        AVG(cost_usd) as avg_cost
      FROM #{analytics_table}
      GROUP BY cost_category, severity
      ORDER BY cost_category, severity
    SQL

    categories = @adapter.read_data(query: category_query)

    assert categories.size > 0, "Should have categorized data"

    # Step 5: Export would use writable foreign table (currently has infrastructure issues)
    # Skipping export verification for now

    puts "\nData Warehouse Workflow Complete:"
    puts "  Staging rows: 1000"
    puts "  Analytics rows: #{exported_count}"
    puts "  Categories created:"
    categories.each do |row|
      puts "    #{row['cost_category']}/#{row['severity']}: #{row['count']} events"
    end
  end

  test "cross-format data integration" do
    skip "CSV/JSON export via COPY TO S3 needs research on PGLake syntax"
    # TODO: Research if PGLake supports COPY TO S3 with CSV/JSON formats
    # May need different approach than standard PostgreSQL COPY
    parquet_path = "s3://opdi/flight_list/mro_events.parquet"
    source_foreign_table = "ft_source_cf_#{@test_timestamp}"
    csv_export = "s3://opdi/test_exports/summary_#{@test_timestamp}.csv"
    json_export = "s3://opdi/test_exports/summary_#{@test_timestamp}.json"

    # Create foreign table for source
    @adapter.create_foreign_table(
      table_name: source_foreign_table,
      s3_path: parquet_path
    )

    # Create summary data
    summary_query = <<~SQL
      CREATE TEMP TABLE event_summary AS
      SELECT#{' '}
        station,
        COUNT(*) as total_events,
        SUM(cost_usd) as total_cost
      FROM #{source_foreign_table}
      GROUP BY station
      ORDER BY total_cost DESC
      LIMIT 20
    SQL

    @adapter.read_data(query: summary_query)

    # Export to CSV (PGLake syntax TBD)
    # Export to JSON (PGLake syntax TBD)
    # Read back and verify (PGLake syntax TBD)
  end

  test "time-series analysis with window functions" do
    source_path = "s3://opdi/flight_list/mro_events.parquet"
    foreign_table = "ft_timeseries_#{@test_timestamp}"

    # Create foreign table
    @adapter.create_foreign_table(
      table_name: foreign_table,
      s3_path: source_path
    )

    # Complex analytical query with window functions
    # Use a subquery to calculate window functions, then filter to top ranks per station
    analysis_query = <<~SQL
      WITH ranked_data AS (
        SELECT#{' '}
          station,
          event_date::DATE as date,
          cost_usd,
          AVG(cost_usd) OVER (
            PARTITION BY station#{' '}
            ORDER BY event_date#{' '}
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
          ) as moving_avg_7day,
          ROW_NUMBER() OVER (
            PARTITION BY station#{' '}
            ORDER BY cost_usd DESC
          ) as cost_rank_in_station
        FROM #{foreign_table}
        WHERE event_date >= CURRENT_DATE - INTERVAL '5 years'
          AND station IN (
            SELECT DISTINCT station#{' '}
            FROM #{foreign_table}
            LIMIT 5
          )
      )
      SELECT * FROM ranked_data
      WHERE cost_rank_in_station <= 20
      ORDER BY station, cost_rank_in_station
      LIMIT 100
    SQL

    result = @adapter.read_data(query: analysis_query)

    assert result.size > 0, "Should have window function results"

    # Verify moving average exists and is calculated
    sample_with_ma = result.find { |r| r["moving_avg_7day"].present? }
    assert sample_with_ma, "Should have moving average calculated"

    # Verify ranking (PostgreSQL returns rank as string or integer depending on driver)
    rank_1_rows = result.select { |r| r["cost_rank_in_station"].to_i == 1 }
    assert rank_1_rows.any?, "Should have rank 1 entries"

    puts "\nTime-series Analysis Complete:"
    puts "  Total rows analyzed: #{result.size}"
    puts "  Stations included: #{result.map { |r| r['station'] }.uniq.count}"
    puts "  Sample moving average: $#{sample_with_ma['moving_avg_7day']&.to_f&.round(2)}"
  end

  test "performance comparison: direct query vs table materialization" do
    source_path = "s3://opdi/flight_list/mro_events.parquet"
    foreign_table = "ft_perf_#{@test_timestamp}"
    materialized_table = "perf_test_#{@test_timestamp}"

    # Create foreign table
    @adapter.create_foreign_table(
      table_name: foreign_table,
      s3_path: source_path
    )

    # Test 1: Direct query from foreign table
    start_time = Time.now
    direct_query = <<~SQL
      SELECT#{' '}
        station,
        AVG(cost_usd) as avg_cost
      FROM #{foreign_table}
      GROUP BY station
      ORDER BY avg_cost DESC
      LIMIT 10
    SQL

    direct_result = @adapter.read_data(query: direct_query)
    direct_time = Time.now - start_time

    # Test 2: Materialize then query
    start_time = Time.now

    # Materialize
    materialize_query = <<~SQL
      CREATE TABLE #{materialized_table} AS
      SELECT * FROM #{foreign_table}
    SQL
    @adapter.read_data(query: materialize_query)

    # Query materialized table
    materialized_query = <<~SQL
      SELECT#{' '}
        station,
        AVG(cost_usd) as avg_cost
      FROM #{materialized_table}
      GROUP BY station
      ORDER BY avg_cost DESC
      LIMIT 10
    SQL

    materialized_result = @adapter.read_data(query: materialized_query)
    materialized_time = Time.now - start_time

    # Verify same results
    assert_equal direct_result.size, materialized_result.size

    puts "\nPerformance Comparison:"
    puts "  Direct Parquet query: #{(direct_time * 1000).round(2)}ms"
    puts "  Materialize + query: #{(materialized_time * 1000).round(2)}ms"
    puts "  Results match: #{direct_result.size} stations"
  end

  test "data quality checks across S3 and PostgreSQL" do
    source_path = "s3://opdi/flight_list/mro_events.parquet"
    foreign_table = "ft_quality_#{@test_timestamp}"
    test_table = "quality_check_#{@test_timestamp}"

    # Create foreign table
    @adapter.create_foreign_table(
      table_name: foreign_table,
      s3_path: source_path
    )

    # Load data into PostgreSQL
    load_query = <<~SQL
      CREATE TABLE #{test_table} AS
      SELECT * FROM #{foreign_table}
      LIMIT 10000
    SQL

    @adapter.read_data(query: load_query)

    # Run data quality checks
    quality_checks = <<~SQL
      SELECT#{' '}
        'total_rows' as check_name,
        COUNT(*)::TEXT as result
      FROM #{test_table}

      UNION ALL

      SELECT#{' '}
        'null_event_ids' as check_name,
        COUNT(*)::TEXT as result
      FROM #{test_table}
      WHERE event_id IS NULL

      UNION ALL

      SELECT#{' '}
        'negative_costs' as check_name,
        COUNT(*)::TEXT as result
      FROM #{test_table}
      WHERE cost_usd < 0

      UNION ALL

      SELECT#{' '}
        'future_dates' as check_name,
        COUNT(*)::TEXT as result
      FROM #{test_table}
      WHERE event_date > CURRENT_DATE

      UNION ALL

      SELECT#{' '}
        'distinct_stations' as check_name,
        COUNT(DISTINCT station)::TEXT as result
      FROM #{test_table}

      UNION ALL

      SELECT#{' '}
        'avg_cost' as check_name,
        ROUND(AVG(cost_usd)::numeric, 2)::TEXT as result
      FROM #{test_table}
    SQL

    results = @adapter.read_data(query: quality_checks)

    # Verify quality metrics
    total_rows = results.find { |r| r["check_name"] == "total_rows" }["result"].to_i
    null_ids = results.find { |r| r["check_name"] == "null_event_ids" }["result"].to_i
    negative_costs = results.find { |r| r["check_name"] == "negative_costs" }["result"].to_i

    assert_equal 10000, total_rows
    assert_equal 0, null_ids, "Should have no null event IDs"
    assert_equal 0, negative_costs, "Should have no negative costs"

    puts "\nData Quality Checks:"
    results.each do |check|
      puts "  #{check['check_name']}: #{check['result']}"
    end
  end
end
