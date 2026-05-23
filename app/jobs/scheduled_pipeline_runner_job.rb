class ScheduledPipelineRunnerJob < ApplicationJob
  queue_as :default

  # This job runs periodically (every minute via Solid Queue recurring jobs)
  # It checks all pipelines with schedules and enqueues execution jobs for those due to run
  def perform
    Rails.logger.info "ScheduledPipelineRunnerJob: Checking for scheduled pipelines..."

    scheduled_pipelines = Pipeline.where.not(schedule: nil).where.not(schedule: "")

    if scheduled_pipelines.empty?
      Rails.logger.debug "ScheduledPipelineRunnerJob: No scheduled pipelines found"
      return
    end

    current_time = Time.current
    pipelines_enqueued = 0

    scheduled_pipelines.each do |pipeline|
      next unless should_run_pipeline?(pipeline, current_time)

      begin
        # Create a new pipeline run
        pipeline_run = pipeline.pipeline_runs.create!(
          status: :pending,
          started_at: current_time
        )

        # Enqueue the execution job
        PipelineExecutionJob.perform_later(pipeline_run.id)

        pipelines_enqueued += 1
        Rails.logger.info "ScheduledPipelineRunnerJob: Enqueued pipeline '#{pipeline.name}' (ID: #{pipeline.id})"
      rescue StandardError => e
        Rails.logger.error "ScheduledPipelineRunnerJob: Failed to enqueue pipeline '#{pipeline.name}' (ID: #{pipeline.id}): #{e.message}"
      end
    end

    Rails.logger.info "ScheduledPipelineRunnerJob: Completed. Enqueued #{pipelines_enqueued} pipeline(s)"
  end

  private

  def should_run_pipeline?(pipeline, current_time)
    # Skip if already running
    if pipeline.running?
      Rails.logger.debug "ScheduledPipelineRunnerJob: Skipping '#{pipeline.name}' - already running"
      return false
    end

    # Parse cron expression
    begin
      cron = Fugit::Cron.parse(pipeline.schedule)

      unless cron
        Rails.logger.warn "ScheduledPipelineRunnerJob: Invalid cron expression for pipeline '#{pipeline.name}': #{pipeline.schedule}"
        return false
      end
    rescue StandardError => e
      Rails.logger.error "ScheduledPipelineRunnerJob: Error parsing cron for pipeline '#{pipeline.name}': #{e.message}"
      return false
    end

    # Check if the pipeline should run at this time
    # We look back 1 minute to see if the cron matched in that window
    last_check_time = current_time - 1.minute
    next_run_time = cron.previous_time(current_time)

    # If there's a next_run_time within the last minute, the pipeline is due
    if next_run_time && next_run_time >= last_check_time
      # Additional check: Don't run if it already ran very recently (within the last minute)
      # This prevents duplicate runs if the job runs multiple times per minute
      if pipeline.last_run_at && pipeline.last_run_at >= last_check_time
        Rails.logger.debug "ScheduledPipelineRunnerJob: Skipping '#{pipeline.name}' - already ran at #{pipeline.last_run_at}"
        return false
      end

      Rails.logger.debug "ScheduledPipelineRunnerJob: Pipeline '#{pipeline.name}' is due (next run was at #{next_run_time})"
      return true
    end

    false
  end
end
