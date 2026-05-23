#!/usr/bin/env ruby

puts "=" * 80
puts "Testing Manufacturing Employment Trends Pipeline Execution"
puts "=" * 80
puts ""

pipeline = Pipeline.find(9)

puts "Pipeline: #{pipeline.name}"
puts "Description: #{pipeline.description}"
puts "Source Connectors: #{pipeline.source_connectors.map(&:name).join(', ')}"
if pipeline.destination_dataset
  puts "Destination Dataset: #{pipeline.destination_dataset.name}"
  puts "Destination Path: #{pipeline.destination_dataset.source_table_path}"
elsif pipeline.destination_connector
  puts "Destination Connector: #{pipeline.destination_connector.name}"
else
  puts "Destination: None"
end
puts ""

puts "Creating pipeline run..."
pipeline_run = pipeline.pipeline_runs.create!(
  status: :pending,
  started_at: Time.current
)

puts "Pipeline Run ID: #{pipeline_run.id}"
puts "Status: #{pipeline_run.status}"
puts ""

begin
  puts "Executing pipeline..."
  puts "-" * 80

  service = PipelineExecutionService.new(pipeline_run: pipeline_run)
  result = service.execute

  puts "-" * 80
  puts ""
  puts "✓ SUCCESS!"
  puts ""
  puts "Results:"
  puts "  Sources loaded: #{result[:sources_loaded]}"
  puts "  Transformation rows: #{result[:transformation_rows]}"
  puts "  Execution time: #{result[:execution_time_ms]}ms"
  puts "  Destination rows written: #{result[:destination_rows]}"
  puts ""
  puts "Message: #{result[:message]}"

  # Update pipeline run
  pipeline_run.update!(
    status: :succeeded,
    completed_at: Time.current,
    row_count: result[:transformation_rows],
    duration: ((Time.current - pipeline_run.started_at) * 1000).to_i
  )

  puts ""
  puts "Pipeline run updated: #{pipeline_run.status}"
  puts "Duration: #{pipeline_run.duration}ms"

rescue => e
  puts "-" * 80
  puts ""
  puts "✗ FAILED!"
  puts ""
  puts "Error: #{e.message}"
  puts ""
  puts "Backtrace:"
  puts e.backtrace.first(10).join("\n")

  pipeline_run.update!(
    status: :failed,
    completed_at: Time.current,
    error_message: e.message,
    duration: ((Time.current - pipeline_run.started_at) * 1000).to_i
  )
end

puts ""
puts "=" * 80
puts "Test Complete"
puts "=" * 80
