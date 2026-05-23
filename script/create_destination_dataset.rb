#!/usr/bin/env ruby
# Create a writable destination dataset for pipeline testing

connector = Connector.find_by(name: 'Snowflake Public Data Test 2')

# For Snowflake public data, we likely don't have write access to PUBLIC_DATA_FREE
# Let's try to use a personal/writable schema if available, or the default PUBLIC schema
# Note: PUBLIC schema might also be read-only depending on permissions

# Create a dataset record for a test output table in PUBLIC schema
dataset = Dataset.create!(
  name: 'Manufacturing Employment Analysis Output',
  description: 'Output dataset for manufacturing employment trends pipeline',
  connector: connector,
  schema_name: 'PUBLIC',  # Try PUBLIC schema first
  table_name: 'MANUFACTURING_EMPLOYMENT_ANALYSIS',
  status: :active,
  schema: {
    columns: [
      { name: 'VARIABLE', type: 'VARCHAR' },
      { name: 'VARIABLE_NAME', type: 'VARCHAR' },
      { name: 'date_code', type: 'INTEGER' },
      { name: 'value', type: 'DOUBLE' }
    ]
  }
)

puts "Created destination dataset:"
puts "  ID: #{dataset.id}"
puts "  Name: #{dataset.name}"
puts "  Path: #{dataset.source_table_path}"
puts "  Status: #{dataset.status}"
puts "\nNote: This dataset may need appropriate write permissions in Snowflake."
puts "If PUBLIC schema is read-only, you'll need to create a personal schema with write access."
