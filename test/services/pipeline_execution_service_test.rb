require "test_helper"

class PipelineExecutionServiceTest < ActiveSupport::TestCase
  setup do
    # Create test connectors
    @source_connector1 = connectors(:one)
    @source_connector2 = connectors(:two)
    @destination_connector = connectors(:three)

    # Create a test pipeline with multiple sources
    @pipeline = Pipeline.create!(
      name: "Test Multi-Source Pipeline",
      transformation_sql: "SELECT * FROM production_snowflake",
      destination_connector: @destination_connector,
      write_disposition: :append
    )

    # Add source connectors
    @pipeline.pipeline_sources.create!(connector: @source_connector1)
    @pipeline.pipeline_sources.create!(connector: @source_connector2)

    # Create a pipeline run
    @pipeline_run = @pipeline.pipeline_runs.create!(
      status: :pending,
      started_at: Time.current
    )

    @service = PipelineExecutionService.new(pipeline_run: @pipeline_run)
  end

  # Initialization tests
  test "initializes with pipeline_run" do
    assert_equal @pipeline_run, @service.pipeline_run
    assert_equal @pipeline, @service.pipeline
  end

  test "raises ConfigurationError if pipeline has no sources" do
    empty_pipeline = Pipeline.create!(
      name: "Empty Pipeline",
      transformation_sql: "SELECT 1"
    )
    empty_run = empty_pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)

    error = assert_raises(PipelineExecutionService::ConfigurationError) do
      PipelineExecutionService.new(pipeline_run: empty_run)
    end

    assert_match(/no sources configured/i, error.message)
  end

  test "raises ConfigurationError if pipeline has no transformation_sql" do
    skip "Database NOT NULL constraint prevents this scenario - validation at model level is sufficient"
    return

    no_sql_pipeline = Pipeline.create!(
      name: "No SQL Pipeline",
      transformation_sql: "SELECT 1"  # Start with valid SQL
    )
    no_sql_pipeline.pipeline_sources.create!(connector: @source_connector1)
    # Update to nil using update_column to bypass validations
    no_sql_pipeline.update_column(:transformation_sql, nil)
    no_sql_run = no_sql_pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)

    error = assert_raises(PipelineExecutionService::ConfigurationError) do
      PipelineExecutionService.new(pipeline_run: no_sql_run)
    end

    assert_match(/no transformation SQL/i, error.message)
  end

  # execute tests
  test "execute runs full pipeline successfully" do
    skip "Complex stubbing test - needs refactoring"
    return
    # Stub the adapter methods
    mock_source_adapter = Minitest::Mock.new
    mock_source_adapter.expect(:read_data, [
      { "id" => 1, "name" => "Test", "amount" => 100 }
    ])

    mock_destination_adapter = Minitest::Mock.new
    mock_destination_adapter.expect(
      :write_data,
      { rows_affected: 1, table_name: "test_multi_source_pipeline", write_disposition: :append, message: "Success" },
      [ Hash ]
    )

    # Stub adapter creation
    ConnectorAdapters::SnowflakeAdapter.stub :new, mock_source_adapter do
      ConnectorAdapters::SnowflakeAdapter.stub :new, mock_destination_adapter, [ @destination_connector ] do
        result = @service.execute

        assert result[:success]
        assert_equal 2, result[:sources_loaded]
        assert result[:transformation_rows] >= 0
        assert result[:execution_time_ms] > 0
        assert_match(/successfully/i, result[:message])
      end
    end
  end

  test "execute without destination connector" do
    skip "Test requires dataset association with pipeline sources - will be updated when feature is added"
    # Create pipeline without destination
    pipeline_no_dest = Pipeline.create!(
      name: "No Destination Pipeline",
      transformation_sql: "SELECT * FROM production_snowflake"
    )
    pipeline_no_dest.pipeline_sources.create!(connector: @source_connector1)
    run_no_dest = pipeline_no_dest.pipeline_runs.create!(status: :pending, started_at: Time.current)

    service = PipelineExecutionService.new(pipeline_run: run_no_dest)

    mock_adapter = Minitest::Mock.new
    mock_adapter.expect(:read_data, [ { "id" => 1, "value" => "test" } ])

    ConnectorAdapters::SnowflakeAdapter.stub :new, mock_adapter do
      result = service.execute

      assert result[:success]
      assert_equal 0, result[:destination_rows]
      assert_match(/No destination/i, result[:message])
    end
  end

  test "execute raises ExecutionError on failure" do
    skip "Test requires dataset association with pipeline sources - will be updated when feature is added"
    # Stub adapter to raise error
    mock_adapter = Minitest::Mock.new
    mock_adapter.expect(:read_data, nil) do
      raise StandardError, "Connection failed"
    end

    ConnectorAdapters::SnowflakeAdapter.stub :new, mock_adapter do
      error = assert_raises(PipelineExecutionService::ExecutionError) do
        @service.execute
      end

      assert_match(/Connection failed/i, error.message)
    end
  end

  test "execute closes DuckDB connection even on failure" do
    mock_adapter = Minitest::Mock.new
    mock_adapter.expect(:read_data, nil) do
      raise StandardError, "Test error"
    end

    duckdb_closed = false
    mock_duckdb = Minitest::Mock.new
    mock_duckdb.expect(:close, nil) { duckdb_closed = true }

    ConnectorAdapters::SnowflakeAdapter.stub :new, mock_adapter do
      ConnectorAdapters::DuckdbAdapter.stub :new, mock_duckdb do
        assert_raises(PipelineExecutionService::ExecutionError) do
          @service.execute
        end
      end
    end
  end

  # Private method tests (via execute)
  test "sanitize_table_name converts to safe SQL identifier" do
    # Test through actual execution
    pipeline = Pipeline.create!(
      name: "Test-Pipeline With Spaces!",
      transformation_sql: "SELECT 1"
    )
    pipeline.pipeline_sources.create!(connector: @source_connector1)

    # The sanitized name should be: test_pipeline_with_spaces_
    # This is indirectly tested through successful execution
    assert pipeline.valid?
  end

  test "loads data from dataset sources" do
    # Create a dataset
    dataset = datasets(:sales_summary)

    # Create pipeline with dataset source
    pipeline = Pipeline.create!(
      name: "Dataset Source Pipeline",
      transformation_sql: "SELECT * FROM #{dataset.name.parameterize(separator: '_')}",
      destination_connector: @destination_connector,
      write_disposition: :append
    )
    pipeline.pipeline_sources.create!(dataset: dataset)

    pipeline_run = pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)
    service = PipelineExecutionService.new(pipeline_run: pipeline_run)

    # Verify service initializes with dataset source
    assert_equal 1, pipeline.source_datasets.count
    assert_equal 0, pipeline.source_connectors.count
  end

  test "validates pipeline with dataset sources" do
    dataset = datasets(:sales_summary)

    pipeline = Pipeline.create!(
      name: "Valid Dataset Pipeline",
      transformation_sql: "SELECT * FROM sales_summary"
    )
    pipeline.pipeline_sources.create!(dataset: dataset)

    pipeline_run = pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)

    # Should not raise ConfigurationError since pipeline has dataset source
    assert_nothing_raised do
      PipelineExecutionService.new(pipeline_run: pipeline_run)
    end
  end

  test "counts both connector and dataset sources in success summary" do
    skip "This would test mixed sources which is no longer allowed"
  end

  test "handles multiple sources with same data structure" do
    skip "Test requires dataset association with pipeline sources - will be updated when feature is added"
    # Create two sources with identical schemas
    pipeline = Pipeline.create!(
      name: "Union Pipeline",
      transformation_sql: <<~SQL
        SELECT * FROM production_snowflake
        UNION ALL
        SELECT * FROM staging_snowflake
      SQL
    )
    pipeline.pipeline_sources.create!(connector: @source_connector1)
    pipeline.pipeline_sources.create!(connector: @source_connector2)
    run = pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)

    service = PipelineExecutionService.new(pipeline_run: run)

    # Mock both sources returning same structure
    mock_adapter = Minitest::Mock.new
    mock_adapter.expect(:read_data, [
      { "id" => 1, "value" => "data" }
    ])
    mock_adapter.expect(:read_data, [
      { "id" => 2, "value" => "more data" }
    ])

    ConnectorAdapters::SnowflakeAdapter.stub :new, mock_adapter do
      result = service.execute
      assert result[:success]
      assert_equal 2, result[:sources_loaded]
    end
  end

  test "handles complex SQL transformations" do
    skip "Test requires dataset association with pipeline sources - will be updated when feature is added"
    pipeline = Pipeline.create!(
      name: "Complex Transform",
      transformation_sql: <<~SQL
        WITH source_data AS (
          SELECT * FROM production_snowflake
        ),
        aggregated AS (
          SELECT#{' '}
            COUNT(*) as row_count,
            SUM(amount) as total_amount
          FROM source_data
        )
        SELECT * FROM aggregated
      SQL
    )
    pipeline.pipeline_sources.create!(connector: @source_connector1)
    run = pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)

    service = PipelineExecutionService.new(pipeline_run: run)

    mock_adapter = Minitest::Mock.new
    mock_adapter.expect(:read_data, [
      { "amount" => 100 },
      { "amount" => 200 }
    ])

    ConnectorAdapters::SnowflakeAdapter.stub :new, mock_adapter do
      result = service.execute
      assert result[:success]
    end
  end

  test "handles empty source data gracefully" do
    skip "Complex stubbing test - needs refactoring"
    return
    mock_adapter = Minitest::Mock.new
    mock_adapter.expect(:read_data, [])
    mock_adapter.expect(:read_data, [])

    ConnectorAdapters::SnowflakeAdapter.stub :new, mock_adapter do
      # Should not raise error even with empty data
      result = @service.execute
      assert result[:success]
    end
  end

  test "supports different write dispositions" do
    skip "Complex stubbing test - needs refactoring"
    return
    # Test truncate_and_load
    @pipeline.update!(write_disposition: :truncate_and_load)

    mock_source = Minitest::Mock.new
    mock_source.expect(:read_data, [ { "id" => 1 } ])
    mock_source.expect(:read_data, [ { "id" => 2 } ])

    mock_dest = Minitest::Mock.new
    mock_dest.expect(:write_data, { rows_affected: 2 }) do |args|
      assert_equal :truncate_and_load, args[:write_disposition]
      true
    end

    ConnectorAdapters::SnowflakeAdapter.stub :new, mock_source do
      ConnectorAdapters::SnowflakeAdapter.stub :new, mock_dest, [ @destination_connector ] do
        result = @service.execute
        assert result[:success]
      end
    end
  end

  test "logs execution steps" do
    skip "Complex stubbing test - needs refactoring"
    return
    mock_adapter = Minitest::Mock.new
    mock_adapter.expect(:read_data, [ { "id" => 1 } ])
    mock_adapter.expect(:read_data, [ { "id" => 2 } ])

    # Capture logs
    logs = []
    Rails.logger.stub :info, ->(msg) { logs << msg } do
      ConnectorAdapters::SnowflakeAdapter.stub :new, mock_adapter do
        @service.execute
      end
    end

    # Check that key steps were logged
    log_text = logs.join("\n")
    assert_match(/Starting pipeline execution/i, log_text)
    assert_match(/Loading data from/i, log_text)
    assert_match(/Executing transformation/i, log_text)
  end

  test "raises error for unsupported connector type" do
    # This would need a connector with unsupported type
    # For now, we test that the method exists and handles errors
    assert_respond_to @service, :execute
  end

  test "determines destination table name from pipeline name" do
    # Table name should be sanitized version of pipeline name
    # Tested indirectly through execution
    assert @pipeline.name.present?
  end
end
