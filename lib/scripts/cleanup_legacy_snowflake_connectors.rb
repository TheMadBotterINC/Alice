#!/usr/bin/env ruby
# Script to clean up legacy Snowflake connectors without private keys
# and their associated pipelines and datasets
#
# Usage: bin/rails runner lib/scripts/cleanup_legacy_snowflake_connectors.rb

puts "=" * 80
puts "Legacy Snowflake Connector Cleanup Script"
puts "=" * 80
puts ""

# Find all Snowflake connectors without private keys
legacy_connectors = Connector.where(connector_type: "snowflake").select do |c|
  c.config["private_key"].blank?
end

if legacy_connectors.empty?
  puts "✓ No legacy connectors found. All Snowflake connectors have private keys."
  exit 0
end

puts "Found #{legacy_connectors.count} legacy Snowflake connector(s) without private keys:"
puts ""

# Summary of what will be deleted
total_datasets = 0
total_pipelines = 0
total_pipeline_runs = 0
total_pipeline_sources = 0

legacy_connectors.each do |connector|
  puts "Connector: #{connector.name} (ID: #{connector.id})"

  datasets = Dataset.where(connector_id: connector.id)
  pipeline_sources = PipelineSource.where(connector_id: connector.id)
  pipelines_as_source = pipeline_sources.map(&:pipeline).uniq
  pipelines_as_dest = Pipeline.where(destination_connector_id: connector.id)
  all_pipelines = (pipelines_as_source + pipelines_as_dest).uniq

  pipeline_runs = all_pipelines.flat_map(&:pipeline_runs).uniq

  puts "  - Datasets: #{datasets.count}"
  if datasets.any?
    datasets.each { |d| puts "    • #{d.name}" }
  end

  puts "  - Pipelines: #{all_pipelines.count}"
  if all_pipelines.any?
    all_pipelines.each { |p| puts "    • #{p.name}" }
  end

  puts "  - Pipeline Runs: #{pipeline_runs.count}"
  puts "  - Pipeline Sources: #{pipeline_sources.count}"
  puts ""

  total_datasets += datasets.count
  total_pipelines += all_pipelines.count
  total_pipeline_runs += pipeline_runs.count
  total_pipeline_sources += pipeline_sources.count
end

puts "-" * 80
puts "SUMMARY"
puts "-" * 80
puts "Total Connectors to delete: #{legacy_connectors.count}"
puts "Total Datasets to delete: #{total_datasets}"
puts "Total Pipelines to delete: #{total_pipelines}"
puts "Total Pipeline Runs to delete: #{total_pipeline_runs}"
puts "Total Pipeline Sources to delete: #{total_pipeline_sources}"
puts ""

# Confirmation prompt
print "Do you want to proceed with deletion? (yes/no): "
response = STDIN.gets.chomp.downcase

unless response == "yes"
  puts ""
  puts "❌ Cleanup cancelled. No changes made."
  exit 0
end

puts ""
puts "Starting cleanup..."
puts ""

# Perform deletion with proper dependency handling
begin
  ActiveRecord::Base.transaction do
  legacy_connectors.each do |connector|
    puts "Processing connector: #{connector.name}..."

    # Find all associated pipelines
    pipeline_sources = PipelineSource.where(connector_id: connector.id)
    pipelines_as_source = pipeline_sources.map(&:pipeline).uniq
    pipelines_as_dest = Pipeline.where(destination_connector_id: connector.id)
    all_pipelines = (pipelines_as_source + pipelines_as_dest).uniq

    # Delete pipeline runs first
    all_pipelines.each do |pipeline|
      run_count = pipeline.pipeline_runs.count
      if run_count > 0
        pipeline.pipeline_runs.destroy_all
        puts "  ✓ Deleted #{run_count} pipeline run(s) for pipeline: #{pipeline.name}"
      end
    end

    # Delete pipeline sources
    source_count = pipeline_sources.count
    if source_count > 0
      pipeline_sources.destroy_all
      puts "  ✓ Deleted #{source_count} pipeline source(s)"
    end

    # Delete pipelines
    all_pipelines.each do |pipeline|
      pipeline.destroy!
      puts "  ✓ Deleted pipeline: #{pipeline.name}"
    end

    # Delete datasets
    datasets = Dataset.where(connector_id: connector.id)
    datasets.each do |dataset|
      dataset.destroy!
      puts "  ✓ Deleted dataset: #{dataset.name}"
    end

    # Finally delete the connector
    connector.destroy!
    puts "  ✓ Deleted connector: #{connector.name}"
    puts ""
  end

  puts "=" * 80
  puts "✅ CLEANUP COMPLETE"
  puts "=" * 80
  puts ""
  puts "Successfully deleted:"
  puts "  - #{legacy_connectors.count} connector(s)"
  puts "  - #{total_datasets} dataset(s)"
  puts "  - #{total_pipelines} pipeline(s)"
  puts "  - #{total_pipeline_runs} pipeline run(s)"
  puts "  - #{total_pipeline_sources} pipeline source(s)"
  puts ""
  puts "All legacy Snowflake connectors without private keys have been removed."
  end
rescue => e
  puts ""
  puts "❌ ERROR during cleanup:"
  puts e.message
  puts e.backtrace.first(5).join("\n")
  puts ""
  puts "Transaction rolled back. No changes were made."
  exit 1
end
