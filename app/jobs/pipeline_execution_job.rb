class PipelineExecutionJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(pipeline_run_id)
    pipeline_run = PipelineRun.find(pipeline_run_id)
    pipeline = pipeline_run.pipeline

    Rails.logger.info "Starting pipeline execution for Pipeline ##{pipeline.id} (#{pipeline.name})"

    # Update status to running (keep original started_at from creation)
    pipeline_run.update!(status: :running)

    # Update pipeline status
    pipeline.update!(status: :running)

    begin
      # Execute the pipeline using the service
      service = PipelineExecutionService.new(pipeline_run: pipeline_run)
      result = service.execute

      # Mark as successful
      pipeline_run.update!(
        status: :succeeded,
        completed_at: Time.current,
        logs: build_success_log(result)
      )

      # Update pipeline status and last_run_at
      pipeline.update!(
        status: :succeeded,
        last_run_at: Time.current
      )

      Rails.logger.info "Pipeline execution completed successfully for Pipeline ##{pipeline.id}"

    rescue PipelineExecutionService::ExecutionError, PipelineExecutionService::ConfigurationError => e
      # Handle execution/config errors
      handle_execution_error(pipeline_run, pipeline, e)

    rescue StandardError => e
      # Handle unexpected errors
      handle_unexpected_error(pipeline_run, pipeline, e)
      raise # Re-raise for retry logic
    end
  end

  private

  def build_success_log(result)
    <<~LOG
      Pipeline execution completed successfully

      Sources loaded: #{result[:sources_loaded]}
      Transformation rows: #{result[:transformation_rows]}
      Execution time: #{result[:execution_time_ms]}ms
      Destination rows written: #{result[:destination_rows]}

      #{result[:message]}

      Completed at: #{Time.current}
    LOG
  end

  def handle_execution_error(pipeline_run, pipeline, error)
    Rails.logger.error "Pipeline execution failed for Pipeline ##{pipeline.id}: #{error.message}"

    pipeline_run.update!(
      status: :failed,
      completed_at: Time.current,
      error_message: error.message,
      logs: build_error_log(error)
    )

    pipeline.update!(
      status: :failed,
      last_run_at: Time.current
    )
  end

  def handle_unexpected_error(pipeline_run, pipeline, error)
    Rails.logger.error "Unexpected error in pipeline execution for Pipeline ##{pipeline.id}: #{error.class} - #{error.message}"
    Rails.logger.error error.backtrace.join("\n")

    pipeline_run.update!(
      status: :failed,
      completed_at: Time.current,
      error_message: "Unexpected error: #{error.class} - #{error.message}",
      logs: build_error_log(error, include_backtrace: true)
    )

    pipeline.update!(status: :failed)
  end

  def build_error_log(error, include_backtrace: false)
    log = <<~LOG
      Pipeline execution failed

      Error: #{error.message}
      Error class: #{error.class}

      Failed at: #{Time.current}
    LOG

    if include_backtrace
      log += "\n\nBacktrace:\n#{error.backtrace.first(10).join("\n")}"
    end

    log
  end
end
