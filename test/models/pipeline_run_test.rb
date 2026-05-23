require "test_helper"

class PipelineRunTest < ActiveSupport::TestCase
  def setup
    @connector = connectors(:one)
    @pipeline = Pipeline.create!(
      name: "Test Pipeline",
      transformation_sql: "SELECT 1"
    )
    @pipeline.pipeline_sources.create!(connector: @connector)
    @pipeline_run = PipelineRun.new(pipeline: @pipeline)
  end

  test "should be valid with valid attributes" do
    assert @pipeline_run.valid?
  end

  test "should require pipeline" do
    @pipeline_run.pipeline = nil
    assert_not @pipeline_run.valid?
  end

  test "should have pending status by default" do
    run = PipelineRun.new
    assert_equal "pending", run.status
  end

  test "should support status enum" do
    @pipeline_run.save!

    @pipeline_run.running!
    assert @pipeline_run.running?

    @pipeline_run.succeeded!
    assert @pipeline_run.succeeded?

    @pipeline_run.failed!
    assert @pipeline_run.failed?
  end

  test "set_started_at callback sets started_at" do
    @pipeline_run.started_at = nil
    @pipeline_run.save!
    assert_not_nil @pipeline_run.started_at
  end

  test "belongs to pipeline" do
    @pipeline_run.save!
    assert_equal @pipeline, @pipeline_run.pipeline
  end

  test "complete_successfully! updates status and completed_at" do
    @pipeline_run.save!
    @pipeline_run.complete_successfully!(row_count: 100)

    @pipeline_run.reload
    assert @pipeline_run.succeeded?
    assert_not_nil @pipeline_run.completed_at
    assert_equal 100, @pipeline_run.row_count
  end

  test "complete_with_failure! updates status and error_message" do
    @pipeline_run.save!
    @pipeline_run.complete_with_failure!("Test error")

    @pipeline_run.reload
    assert @pipeline_run.failed?
    assert_not_nil @pipeline_run.completed_at
    assert_equal "Test error", @pipeline_run.error_message
  end

  test "mark_as_running! updates status" do
    @pipeline_run.save!
    @pipeline_run.mark_as_running!

    @pipeline_run.reload
    assert @pipeline_run.running?
  end

  test "duration_in_seconds calculates correctly" do
    @pipeline_run.started_at = Time.current
    @pipeline_run.completed_at = Time.current + 5.seconds

    assert_equal 5, @pipeline_run.duration_in_seconds
  end

  test "duration_in_seconds returns nil when not completed" do
    @pipeline_run.started_at = Time.current
    @pipeline_run.completed_at = nil

    assert_nil @pipeline_run.duration_in_seconds
  end

  test "calculate_duration callback sets duration" do
    @pipeline_run.save!
    @pipeline_run.update(completed_at: @pipeline_run.started_at + 10.seconds)

    @pipeline_run.reload
    assert_equal 10, @pipeline_run.duration
  end

  test "recent scope orders by started_at desc" do
    PipelineRun.delete_all

    first = @pipeline.pipeline_runs.create!(started_at: 2.hours.ago)
    second = @pipeline.pipeline_runs.create!(started_at: 1.hour.ago)

    recent = PipelineRun.recent
    assert_equal second, recent.first
    assert_equal first, recent.last
  end

  test "for_pipeline scope filters by pipeline_id" do
    other_pipeline = Pipeline.create!(
      name: "Other Pipeline",
      transformation_sql: "SELECT 2"
    )
    other_pipeline.pipeline_sources.create!(connector: @connector)

    @pipeline.pipeline_runs.create!(started_at: Time.current)
    other_run = other_pipeline.pipeline_runs.create!(started_at: Time.current)

    runs = PipelineRun.for_pipeline(@pipeline.id)
    assert_not_includes runs, other_run
  end

  test "status_variant returns correct variant" do
    @pipeline_run.status = :succeeded
    assert_equal :success, @pipeline_run.status_variant

    @pipeline_run.status = :failed
    assert_equal :danger, @pipeline_run.status_variant

    @pipeline_run.status = :running
    assert_equal :warning, @pipeline_run.status_variant

    @pipeline_run.status = :pending
    assert_equal :gray, @pipeline_run.status_variant
  end
end
