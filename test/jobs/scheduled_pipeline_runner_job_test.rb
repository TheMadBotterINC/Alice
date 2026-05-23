require "test_helper"

class ScheduledPipelineRunnerJobTest < ActiveJob::TestCase
  setup do
    @connector = connectors(:one)
    # Clear any existing pipeline data to avoid interference
    PipelineRun.delete_all
    PipelineSource.delete_all
    Pipeline.delete_all
  end

  test "enqueues pipelines due to run based on cron schedule" do
    # Create a pipeline scheduled to run every minute
    pipeline = Pipeline.create!(
      name: "Scheduled Pipeline",
      transformation_sql: "SELECT 1",
      schedule: "* * * * *" # Every minute
    )
    pipeline.pipeline_sources.create!(connector: @connector)

    # Freeze time to ensure consistent cron evaluation
    travel_to Time.zone.parse("2025-01-15 10:00:00") do
      assert_enqueued_with(job: PipelineExecutionJob) do
        ScheduledPipelineRunnerJob.perform_now
      end
    end

    # Verify a pipeline run was created
    assert_equal 1, pipeline.pipeline_runs.count
    assert_equal "pending", pipeline.pipeline_runs.first.status
  end

  test "does not enqueue pipelines that are not due to run" do
    # Create a pipeline scheduled to run at 2 AM daily
    pipeline = Pipeline.create!(
      name: "Daily Pipeline",
      transformation_sql: "SELECT 1",
      schedule: "0 2 * * *" # 2 AM daily
    )
    pipeline.pipeline_sources.create!(connector: @connector)

    # Run at 10 AM, should not enqueue
    travel_to Time.zone.parse("2025-01-15 10:00:00") do
      assert_no_enqueued_jobs do
        ScheduledPipelineRunnerJob.perform_now
      end
    end

    # Verify no pipeline run was created
    assert_equal 0, pipeline.pipeline_runs.count
  end

  test "enqueues pipelines scheduled for specific time when that time arrives" do
    # Create a pipeline scheduled to run at 10 AM daily
    pipeline = Pipeline.create!(
      name: "Morning Pipeline",
      transformation_sql: "SELECT 1",
      schedule: "0 10 * * *" # 10 AM daily
    )
    pipeline.pipeline_sources.create!(connector: @connector)

    # Run at 10:00:30 AM (30 seconds after scheduled time - within the 1 minute window)
    travel_to Time.zone.parse("2025-01-15 10:00:30") do
      assert_enqueued_with(job: PipelineExecutionJob) do
        ScheduledPipelineRunnerJob.perform_now
      end
    end

    assert_equal 1, pipeline.pipeline_runs.count
  end

  test "does not enqueue already running pipelines" do
    pipeline = Pipeline.create!(
      name: "Running Pipeline",
      transformation_sql: "SELECT 1",
      schedule: "* * * * *", # Every minute
      status: :running
    )
    pipeline.pipeline_sources.create!(connector: @connector)

    travel_to Time.zone.parse("2025-01-15 10:00:00") do
      assert_no_enqueued_jobs do
        ScheduledPipelineRunnerJob.perform_now
      end
    end

    assert_equal 0, pipeline.pipeline_runs.count
  end

  test "does not enqueue pipelines that ran very recently" do
    pipeline = Pipeline.create!(
      name: "Recent Pipeline",
      transformation_sql: "SELECT 1",
      schedule: "* * * * *", # Every minute
      last_run_at: 30.seconds.ago
    )
    pipeline.pipeline_sources.create!(connector: @connector)

    travel_to Time.zone.parse("2025-01-15 10:00:00") do
      assert_no_enqueued_jobs do
        ScheduledPipelineRunnerJob.perform_now
      end
    end

    assert_equal 0, pipeline.pipeline_runs.count
  end

  test "handles pipelines with no schedule gracefully" do
    pipeline = Pipeline.create!(
      name: "Manual Pipeline",
      transformation_sql: "SELECT 1",
      schedule: nil
    )
    pipeline.pipeline_sources.create!(connector: @connector)

    assert_nothing_raised do
      ScheduledPipelineRunnerJob.perform_now
    end

    assert_equal 0, pipeline.pipeline_runs.count
  end

  test "handles pipelines with empty schedule string" do
    pipeline = Pipeline.create!(
      name: "Manual Pipeline",
      transformation_sql: "SELECT 1",
      schedule: ""
    )
    pipeline.pipeline_sources.create!(connector: @connector)

    assert_nothing_raised do
      ScheduledPipelineRunnerJob.perform_now
    end

    assert_equal 0, pipeline.pipeline_runs.count
  end

  test "handles invalid cron expressions gracefully" do
    pipeline = Pipeline.create!(
      name: "Invalid Cron Pipeline",
      transformation_sql: "SELECT 1",
      schedule: "invalid cron expression"
    )
    pipeline.pipeline_sources.create!(connector: @connector)

    # Should not raise error, just log warning
    assert_nothing_raised do
      ScheduledPipelineRunnerJob.perform_now
    end

    assert_equal 0, pipeline.pipeline_runs.count
  end

  test "enqueues multiple pipelines when multiple are due" do
    # Create two pipelines scheduled to run every minute
    pipeline1 = Pipeline.create!(
      name: "Pipeline 1",
      transformation_sql: "SELECT 1",
      schedule: "* * * * *"
    )
    pipeline1.pipeline_sources.create!(connector: @connector)

    pipeline2 = Pipeline.create!(
      name: "Pipeline 2",
      transformation_sql: "SELECT 2",
      schedule: "* * * * *"
    )
    pipeline2.pipeline_sources.create!(connector: @connector)

    travel_to Time.zone.parse("2025-01-15 10:00:00") do
      assert_enqueued_jobs 2, only: PipelineExecutionJob do
        ScheduledPipelineRunnerJob.perform_now
      end
    end

    assert_equal 1, pipeline1.pipeline_runs.count
    assert_equal 1, pipeline2.pipeline_runs.count
  end

  test "works with every 5 minutes cron format" do
    pipeline = Pipeline.create!(
      name: "Every 5 Minutes Pipeline",
      transformation_sql: "SELECT 1",
      schedule: "*/5 * * * *"
    )
    pipeline.pipeline_sources.create!(connector: @connector)

    # Should run at 10:00
    travel_to Time.zone.parse("2025-01-15 10:00:30") do
      assert_enqueued_with(job: PipelineExecutionJob) do
        ScheduledPipelineRunnerJob.perform_now
      end
    end
    assert_equal 1, pipeline.pipeline_runs.count

    # Should not run at 10:03 (not a 5-minute boundary)
    travel_to Time.zone.parse("2025-01-15 10:03:00") do
      initial_count = pipeline.pipeline_runs.count
      ScheduledPipelineRunnerJob.perform_now
      assert_equal initial_count, pipeline.pipeline_runs.count
    end
  end

  test "works with every 2 hours cron format" do
    pipeline = Pipeline.create!(
      name: "Every 2 Hours Pipeline",
      transformation_sql: "SELECT 1",
      schedule: "0 */2 * * *"
    )
    pipeline.pipeline_sources.create!(connector: @connector)

    # Should run at 10:00
    travel_to Time.zone.parse("2025-01-15 10:00:30") do
      assert_enqueued_with(job: PipelineExecutionJob) do
        ScheduledPipelineRunnerJob.perform_now
      end
    end
    assert_equal 1, pipeline.pipeline_runs.count

    # Should not run at 11:00 (not a 2-hour boundary)
    travel_to Time.zone.parse("2025-01-15 11:00:00") do
      initial_count = pipeline.pipeline_runs.count
      ScheduledPipelineRunnerJob.perform_now
      assert_equal initial_count, pipeline.pipeline_runs.count
    end
  end

  test "works with weekly schedule on specific day" do
    pipeline = Pipeline.create!(
      name: "Weekly Monday Pipeline",
      transformation_sql: "SELECT 1",
      schedule: "30 9 * * 1" # 9:30 AM every Monday
    )
    pipeline.pipeline_sources.create!(connector: @connector)

    # Should run on Monday 2025-01-20 (which is a Monday)
    travel_to Time.zone.parse("2025-01-20 09:30:30") do
      assert_enqueued_with(job: PipelineExecutionJob) do
        ScheduledPipelineRunnerJob.perform_now
      end
    end
    assert_equal 1, pipeline.pipeline_runs.count

    # Should not run on Tuesday
    travel_to Time.zone.parse("2025-01-21 09:30:00") do
      initial_count = pipeline.pipeline_runs.count
      ScheduledPipelineRunnerJob.perform_now
      assert_equal initial_count, pipeline.pipeline_runs.count
    end
  end

  test "logs appropriate messages during execution" do
    pipeline = Pipeline.create!(
      name: "Logged Pipeline",
      transformation_sql: "SELECT 1",
      schedule: "* * * * *"
    )
    pipeline.pipeline_sources.create!(connector: @connector)

    travel_to Time.zone.parse("2025-01-15 10:00:00") do
      # Capture logs
      log_output = capture_log do
        ScheduledPipelineRunnerJob.perform_now
      end

      assert_match(/Checking for scheduled pipelines/, log_output)
      assert_match(/Enqueued pipeline.*Logged Pipeline/, log_output)
      assert_match(/Completed.*Enqueued 1 pipeline/, log_output)
    end
  end

  private

  def capture_log
    old_logger = Rails.logger
    log_output = StringIO.new
    Rails.logger = Logger.new(log_output)

    yield

    log_output.string
  ensure
    Rails.logger = old_logger
  end
end
