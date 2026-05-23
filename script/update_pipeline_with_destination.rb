#!/usr/bin/env ruby
# Update Manufacturing Employment Trends pipeline with destination dataset

pipeline = Pipeline.find_by(name: 'Manufacturing Employment Trends')
destination = Dataset.find_by(name: 'Manufacturing Employment Analysis Output')

if pipeline.nil?
  puts "Pipeline not found!"
  exit 1
end

if destination.nil?
  puts "Destination dataset not found!"
  exit 1
end

pipeline.update!(
  destination_dataset_id: destination.id,
  destination_connector_id: nil  # Clear the old connector-based destination
)

puts "Pipeline updated successfully!"
puts ""
puts "Pipeline: #{pipeline.name}"
puts "Source connectors: #{pipeline.source_connectors.map(&:name).join(', ')}"
puts "Destination dataset: #{pipeline.destination_dataset&.name || 'NONE'}"
puts "Destination path: #{pipeline.destination_dataset&.source_table_path}"
puts "Write disposition: #{pipeline.write_disposition}"
