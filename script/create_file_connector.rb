#!/usr/bin/env ruby
# Create file connector for CSV/Excel output

puts "=" * 80
puts "Creating File Connector for Pipeline Output"
puts "=" * 80

# Create file connector for writing
connector = Connector.create!(
  name: "Local File Output",
  connector_type: "file",
  config: {
    output_directory: "data/output",
    file_extension: ".csv"  # Can be .csv, .tsv, or .xlsx
  },
  status: :connected
)

puts "\n✓ Created connector: #{connector.name}"
puts "  Type: #{connector.connector_type}"
puts "  Output directory: #{connector.config['output_directory']}"
puts "  File extension: #{connector.config['file_extension']}"

# Test the connector
adapter = ConnectorAdapters::FileAdapter.new(connector)
if adapter.test_connection
  puts "\n✓ Connection test passed!"
else
  puts "\n✗ Connection test failed!"
  exit 1
end

# Create a dataset for the output
dataset = Dataset.create!(
  name: "Manufacturing Employment CSV Output",
  description: "CSV export of manufacturing employment analysis",
  connector: connector,
  schema_name: "local",  # Not really used for files but required
  table_name: "manufacturing_employment_analysis",
  status: :active,
  schema: {
    columns: [
      { name: "VARIABLE", type: "VARCHAR" },
      { name: "VARIABLE_NAME", type: "VARCHAR" },
      { name: "date_code", type: "INTEGER" },
      { name: "value", type: "DOUBLE" }
    ]
  }
)

puts "\n✓ Created dataset: #{dataset.name}"
puts "  Output file will be: data/output/manufacturing_employment_analysis.csv"
puts "\nConnector ID: #{connector.id}"
puts "Dataset ID: #{dataset.id}"
