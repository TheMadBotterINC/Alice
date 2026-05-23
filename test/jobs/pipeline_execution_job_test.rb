require "test_helper"

class PipelineExecutionJobTest < ActiveJob::TestCase
  setup do
    @connector = connectors(:one)
    @pipeline = Pipeline.create!(
      name: "Test Pipeline",
      transformation_sql: "SELECT * FROM test_table"
    )
    @pipeline.pipeline_sources.create!(connector: @connector)

    @pipeline_run = @pipeline.pipeline_runs.create!(
      status: :pending,
      started_at: Time.current
    )
  end

  # Job enqueuing tests
  test "job is enqueued" do
    assert_enqueued_with(job: PipelineExecutionJob, args: [ @pipeline_run.id ]) do
      PipelineExecutionJob.perform_later(@pipeline_run.id)
    end
  end

  test "job is in default queue" do
    assert_equal "default", PipelineExecutionJob.new.queue_name
  end

  # Successful execution tests
  test "perform updates pipeline_run to running then succeeded" do
    mock_service = Minitest::Mock.new
    mock_service.expect(:execute, {
      success: true,
      sources_loaded: 1,
      transformation_rows: 100,
      execution_time_ms: 1500,
      destination_rows: 100,
      message: "Pipeline executed successfully"
    })

    PipelineExecutionService.stub :new, mock_service do
      PipelineExecutionJob.perform_now(@pipeline_run.id)
    end

    @pipeline_run.reload
    @pipeline.reload

    assert_equal "succeeded", @pipeline_run.status
    assert_equal "succeeded", @pipeline.status
    assert_not_nil @pipeline_run.completed_at
    assert_not_nil @pipeline.last_run_at
    assert_match(/successfully/i, @pipeline_run.logs)
  end

  test "perform logs include execution details" do
    mock_service = Minitest::Mock.new
    mock_service.expect(:execute, {
      success: true,
      sources_loaded: 2,
      transformation_rows: 500,
      execution_time_ms: 2000,
      destination_rows: 500,
      message: "Test message"
    })

    PipelineExecutionService.stub :new, mock_service do
      PipelineExecutionJob.perform_now(@pipeline_run.id)
    end

    @pipeline_run.reload

    assert_match(/Sources loaded: 2/, @pipeline_run.logs)
    assert_match(/Transformation rows: 500/, @pipeline_run.logs)
    assert_match(/Execution time: 2000ms/, @pipeline_run.logs)
    assert_match(/Destination rows written: 500/, @pipeline_run.logs)
  end

  # Error handling tests
  test "perform handles ExecutionError" do
    mock_service = Minitest::Mock.new
    mock_service.expect(:execute, nil) do
      raise PipelineExecutionService::ExecutionError, "Query failed"
    end

    PipelineExecutionService.stub :new, mock_service do
      PipelineExecutionJob.perform_now(@pipeline_run.id)
    end

    @pipeline_run.reload
    @pipeline.reload

    assert_equal "failed", @pipeline_run.status
    assert_equal "failed", @pipeline.status
    assert_equal "Query failed", @pipeline_run.error_message
    assert_match(/Pipeline execution failed/i, @pipeline_run.logs)
    assert_not_nil @pipeline_run.completed_at
  end

  test "perform handles ConfigurationError" do
    # Create pipeline without sources to trigger ConfigurationError
    bad_pipeline = Pipeline.create!(
      name: "Bad Pipeline",
      transformation_sql: "SELECT 1"
    )
    bad_run = bad_pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)

    PipelineExecutionJob.perform_now(bad_run.id)

    bad_run.reload

    assert_equal "failed", bad_run.status
    assert_match(/no sources configured/i, bad_run.error_message)
  end

  test "perform re-raises StandardError for retry logic" do
    skip "Complex stubbing with lambda - needs refactoring"
    return

    # Use a stub that raises when execute is called
    PipelineExecutionService.stub :new, ->(_) {
      mock_service = Minitest::Mock.new
      mock_service.expect(:execute) { raise StandardError, "Unexpected error" }
      mock_service
    } do
      assert_raises(StandardError) do
        PipelineExecutionJob.perform_now(@pipeline_run.id)
      end
    end

    @pipeline_run.reload

    assert_equal "failed", @pipeline_run.status
    assert_match(/Unexpected error/i, @pipeline_run.error_message)
  end

  # Status update tests
  test "updates pipeline status to running at start" do
    check_called = false

    mock_service = Minitest::Mock.new
    mock_service.expect(:execute, {
      success: true,
      sources_loaded: 1,
      transformation_rows: 10,
      execution_time_ms: 100,
      destination_rows: 10,
      message: "Success"
    }) do
      check_called = true
      @pipeline.reload
      assert_equal "running", @pipeline.status
      @pipeline_run.reload
      assert_equal "running", @pipeline_run.status
    end

    PipelineExecutionService.stub :new, mock_service do
      PipelineExecutionJob.perform_now(@pipeline_run.id)
    end

    assert check_called, "Service execute was not called"
  end

  test "updates last_run_at on pipeline" do
    mock_service = Minitest::Mock.new
    mock_service.expect(:execute, {
      success: true,
      sources_loaded: 1,
      transformation_rows: 10,
      execution_time_ms: 100,
      destination_rows: 10,
      message: "Success"
    })

    travel_to Time.zone.parse("2025-10-09 12:00:00") do
      PipelineExecutionService.stub :new, mock_service do
        PipelineExecutionJob.perform_now(@pipeline_run.id)
      end

      @pipeline.reload
      assert_equal Time.zone.parse("2025-10-09 12:00:00"), @pipeline.last_run_at
    end
  end

  # Error log building tests
  test "build_error_log includes error details" do
    error = StandardError.new("Test error message")
    job = PipelineExecutionJob.new

    log = job.send(:build_error_log, error)

    assert_match(/Pipeline execution failed/, log)
    assert_match(/Test error message/, log)
    assert_match(/StandardError/, log)
  end

  test "build_error_log includes backtrace when requested" do
    error = StandardError.new("Test error")
    error.set_backtrace([ "line 1", "line 2", "line 3" ])

    job = PipelineExecutionJob.new
    log = job.send(:build_error_log, error, include_backtrace: true)

    assert_match(/Backtrace:/, log)
    assert_match(/line 1/, log)
  end

  # Success log building tests
  test "build_success_log includes all metrics" do
    result = {
      sources_loaded: 3,
      transformation_rows: 1000,
      execution_time_ms: 5000,
      destination_rows: 1000,
      message: "Custom success message"
    }

    job = PipelineExecutionJob.new
    log = job.send(:build_success_log, result)

    assert_match(/Sources loaded: 3/, log)
    assert_match(/Transformation rows: 1000/, log)
    assert_match(/Execution time: 5000ms/, log)
    assert_match(/Destination rows written: 1000/, log)
    assert_match(/Custom success message/, log)
  end
end
