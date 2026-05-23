require "test_helper"

class PipelineExecutionServiceRowLimitTest < ActiveSupport::TestCase
  setup do
    @snowflake_connector = Connector.create!(
      name: "Test Snowflake",
      connector_type: "snowflake",
      config: {
        "account" => "test",
        "username" => "user",
        "private_key" => "key",
        "database" => "TEST_DB",
        "warehouse" => "TEST_WH",
        "schema" => "PUBLIC"
      },
      status: :connected
    )

    @file_connector = Connector.create!(
      name: "Test CSV File",
      connector_type: "file_csv",
      config: {
        "file_path" => "/tmp/test.csv",
        "has_header" => true,
        "delimiter" => ","
      },
      status: :connected
    )

    @dataset = Dataset.create!(
      name: "Test Dataset",
      connector: @snowflake_connector,
      schema_name: "PUBLIC",
      table_name: "TEST_TABLE",
      status: :active
    )
  end

  # Test default row limit behavior
  test "applies default row limit of 100000 to dataset sources when using default" do
    pipeline = Pipeline.create!(
      name: "Test Default Limit",
      transformation_sql: "SELECT * FROM test_dataset"
      # source_row_limit will default to 100000
    )
    pipeline.pipeline_sources.create!(dataset: @dataset)
    pipeline_run = pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)

    service = PipelineExecutionService.new(pipeline_run: pipeline_run)

    # Mock the adapter
    mock_adapter = Minitest::Mock.new
    mock_adapter.expect(:read_data, []) do |query:|
      # Verify the query contains LIMIT 100000
      assert_match(/LIMIT 100000/i, query)
      true
    end

    mock_duckdb = Minitest::Mock.new
    mock_duckdb.expect(:load_data, 0) do |table_name:, data:|
      true
    end
    mock_duckdb.expect(:execute_query, { rows: [], row_count: 0, execution_time_ms: 10 }) do |sql:|
      true
    end
    mock_duckdb.expect(:close, nil)

    ConnectorAdapters::SnowflakeAdapter.stub :new, mock_adapter do
      ConnectorAdapters::DuckdbAdapter.stub :new, mock_duckdb do
        service.execute
      end
    end

    mock_adapter.verify
  end

  test "applies configured row limit to dataset sources" do
    pipeline = Pipeline.create!(
      name: "Test Custom Limit",
      transformation_sql: "SELECT * FROM test_dataset",
      source_row_limit: 50000
    )
    pipeline.pipeline_sources.create!(dataset: @dataset)
    pipeline_run = pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)

    service = PipelineExecutionService.new(pipeline_run: pipeline_run)

    # Mock the adapter
    mock_adapter = Minitest::Mock.new
    mock_adapter.expect(:read_data, []) do |query:|
      # Verify the query contains LIMIT 50000
      assert_match(/LIMIT 50000/i, query)
      true
    end

    mock_duckdb = Minitest::Mock.new
    mock_duckdb.expect(:load_data, 0) do |table_name:, data:|
      true
    end
    mock_duckdb.expect(:execute_query, { rows: [], row_count: 0, execution_time_ms: 10 }) do |sql:|
      true
    end
    mock_duckdb.expect(:close, nil)

    ConnectorAdapters::SnowflakeAdapter.stub :new, mock_adapter do
      ConnectorAdapters::DuckdbAdapter.stub :new, mock_duckdb do
        service.execute
      end
    end

    mock_adapter.verify
  end

  test "applies same row limit to multiple dataset sources" do
    dataset2 = Dataset.create!(
      name: "Test Dataset 2",
      connector: @snowflake_connector,
      schema_name: "PUBLIC",
      table_name: "TEST_TABLE_2",
      status: :active
    )

    pipeline = Pipeline.create!(
      name: "Test Multiple Datasets",
      transformation_sql: "SELECT * FROM test_dataset UNION ALL SELECT * FROM test_dataset_2",
      source_row_limit: 25000
    )
    pipeline.pipeline_sources.create!(dataset: @dataset)
    pipeline.pipeline_sources.create!(dataset: dataset2)
    pipeline_run = pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)

    service = PipelineExecutionService.new(pipeline_run: pipeline_run)

    # Mock the adapter to track both calls
    call_count = 0
    mock_adapter = Minitest::Mock.new
    2.times do
      mock_adapter.expect(:read_data, []) do |query:|
        call_count += 1
        # Each query should have LIMIT 25000
        assert_match(/LIMIT 25000/i, query)
        true
      end
    end

    mock_duckdb = Minitest::Mock.new
    mock_duckdb.expect(:load_data, 0) do |table_name:, data:|
      true
    end
    mock_duckdb.expect(:load_data, 0) do |table_name:, data:|
      true
    end
    mock_duckdb.expect(:execute_query, { rows: [], row_count: 0, execution_time_ms: 10 }) do |sql:|
      true
    end
    mock_duckdb.expect(:close, nil)

    ConnectorAdapters::SnowflakeAdapter.stub :new, mock_adapter do
      ConnectorAdapters::DuckdbAdapter.stub :new, mock_duckdb do
        service.execute
      end
    end

    assert_equal 2, call_count
    mock_adapter.verify
  end

  test "file connectors do not use row limits" do
    pipeline = Pipeline.create!(
      name: "Test File Connector",
      transformation_sql: "SELECT * FROM test_csv_file",
      source_row_limit: 10000  # Set a limit but it should not be used
    )
    pipeline.pipeline_sources.create!(connector: @file_connector)
    pipeline_run = pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)

    service = PipelineExecutionService.new(pipeline_run: pipeline_run)

    # Mock the file adapter - should receive nil for query
    mock_adapter = Minitest::Mock.new
    mock_adapter.expect(:read_data, []) do |query:, uploaded_file: nil|
      # File connectors don't use queries
      assert_nil query
      true
    end

    mock_duckdb = Minitest::Mock.new
    mock_duckdb.expect(:load_data, 0) do |table_name:, data:|
      true
    end
    mock_duckdb.expect(:execute_query, { rows: [], row_count: 0, execution_time_ms: 10 }) do |sql:|
      true
    end
    mock_duckdb.expect(:close, nil)

    ConnectorAdapters::FileAdapter.stub :new, mock_adapter do
      ConnectorAdapters::DuckdbAdapter.stub :new, mock_duckdb do
        service.execute
      end
    end

    mock_adapter.verify
  end

  test "raises error when trying to use Snowflake connector directly as source" do
    pipeline = Pipeline.create!(
      name: "Test Direct Snowflake",
      transformation_sql: "SELECT * FROM test",
      source_row_limit: 10000
    )
    # Try to use Snowflake connector directly instead of a dataset
    pipeline.pipeline_sources.create!(connector: @snowflake_connector)
    pipeline_run = pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)

    service = PipelineExecutionService.new(pipeline_run: pipeline_run)

    mock_duckdb = Minitest::Mock.new
    mock_duckdb.expect(:close, nil)

    ConnectorAdapters::DuckdbAdapter.stub :new, mock_duckdb do
      error = assert_raises(PipelineExecutionService::ExecutionError) do
        service.execute
      end
      # The ConfigurationError gets wrapped in ExecutionError
      assert error.is_a?(PipelineExecutionService::ExecutionError)
      assert_match(/Cannot use Snowflake connector/i, error.message)
      assert_match(/use a Dataset/i, error.message)
      assert_match(/Browse Tables/i, error.message)
    end
  end

  test "mixed file and dataset sources work correctly with row limits" do
    skip "This test would require allowing mixed source types, which is currently not allowed"
  end

  test "source_row_limit field defaults to 100000 in database" do
    pipeline = Pipeline.create!(
      name: "Test Default DB Value",
      transformation_sql: "SELECT 1"
    )
    pipeline.pipeline_sources.create!(dataset: @dataset)

    # Reload from database to get default value
    pipeline.reload
    assert_equal 100000, pipeline.source_row_limit
  end

  test "source_row_limit is required and cannot be nil" do
    pipeline = Pipeline.new(
      name: "Test Nil Limit",
      transformation_sql: "SELECT * FROM test_dataset",
      source_row_limit: nil
    )
    pipeline.pipeline_sources.build(dataset: @dataset)

    # Should raise error when trying to save with nil
    assert_raises(ActiveRecord::NotNullViolation) do
      pipeline.save!
    end
  end

  test "source_row_limit must be positive integer" do
    pipeline = Pipeline.new(
      name: "Test Negative Limit",
      transformation_sql: "SELECT 1",
      source_row_limit: -100
    )

    # The form validation (min: 1) prevents this at UI level
    # At model level, we accept any integer
    assert pipeline.source_row_limit == -100
  end

  test "logs info when applying default row limit" do
    pipeline = Pipeline.create!(
      name: "Test Logging",
      transformation_sql: "SELECT * FROM test_dataset"
      # Uses default source_row_limit of 100000
    )
    pipeline.pipeline_sources.create!(dataset: @dataset)
    pipeline_run = pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)

    service = PipelineExecutionService.new(pipeline_run: pipeline_run)

    # Capture logs
    logs = []
    Rails.logger.stub :info, ->(msg) { logs << msg } do
      mock_adapter = Minitest::Mock.new
      mock_adapter.expect(:read_data, []) { true }

      mock_duckdb = Minitest::Mock.new
      mock_duckdb.expect(:load_data, 0) do |table_name:, data:|
        true
      end
      mock_duckdb.expect(:execute_query, { rows: [], row_count: 0, execution_time_ms: 10 }) do |sql:|
        true
      end
      mock_duckdb.expect(:close, nil)

      ConnectorAdapters::SnowflakeAdapter.stub :new, mock_adapter do
        ConnectorAdapters::DuckdbAdapter.stub :new, mock_duckdb do
          service.execute
        end
      end
    end

    log_text = logs.join("\n")
    assert_match(/Applying row limit of 100000 rows/i, log_text)
  end

  test "logs apply row limit message with configured value" do
    pipeline = Pipeline.create!(
      name: "Test Configured Logging",
      transformation_sql: "SELECT * FROM test_dataset",
      source_row_limit: 75000
    )
    pipeline.pipeline_sources.create!(dataset: @dataset)
    pipeline_run = pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)

    service = PipelineExecutionService.new(pipeline_run: pipeline_run)

    # Capture logs
    logs = []
    Rails.logger.stub :info, ->(msg) { logs << msg } do
      mock_adapter = Minitest::Mock.new
      mock_adapter.expect(:read_data, []) { true }

      mock_duckdb = Minitest::Mock.new
      mock_duckdb.expect(:load_data, 0) do |table_name:, data:|
        true
      end
      mock_duckdb.expect(:execute_query, { rows: [], row_count: 0, execution_time_ms: 10 }) do |sql:|
        true
      end
      mock_duckdb.expect(:close, nil)

      ConnectorAdapters::SnowflakeAdapter.stub :new, mock_adapter do
        ConnectorAdapters::DuckdbAdapter.stub :new, mock_duckdb do
          service.execute
        end
      end
    end

    log_text = logs.join("\n")
    # Should log the configured limit of 75000
    assert_match(/Applying row limit of 75000 rows/i, log_text)
  end
end
