#!/usr/bin/env ruby
# Debug source query building

pipeline = Pipeline.find_by(name: 'Manufacturing Employment Trends')
connector = pipeline.source_connectors.first

puts "=" * 80
puts "Debugging Source Query Building"
puts "=" * 80
puts "\nPipeline: #{pipeline.name}"
puts "Connector: #{connector.name}"
puts "Connector Type: #{connector.connector_type}"
puts "\n"

# Try to find dataset
dataset = Dataset.find_by(connector: connector, schema_name: 'PUBLIC_DATA_FREE',
                          table_name: 'BUREAU_OF_LABOR_STATISTICS_EMPLOYMENT_TIMESERIES')

puts "Dataset lookup result:"
if dataset
  puts "  Found: #{dataset.name}"
  puts "  Source table path: #{dataset.source_table_path}"
else
  puts "  Not found"
  puts "  Connector config database: #{connector.config['database']}"
  puts "  Connector config schema: #{connector.config['schema']}"
end
