#!/usr/bin/env ruby
# Inspect the structure of Snowflake data

conn = Connector.find_by(name: 'Snowflake Public Data Test 2')
adapter = ConnectorAdapters::SnowflakeAdapter.new(conn)

puts "=" * 80
puts "Inspecting Snowflake Data"
puts "=" * 80

query = <<~SQL
  SELECT#{' '}
    DATE,#{' '}
    VALUE,#{' '}
    VARIABLE,#{' '}
    VARIABLE_NAME
  FROM SNOWFLAKE_PUBLIC_DATA_FREE.PUBLIC_DATA_FREE.BUREAU_OF_LABOR_STATISTICS_EMPLOYMENT_TIMESERIES#{' '}
  WHERE VARIABLE_NAME LIKE '%Manufacturing%'#{' '}
  LIMIT 5
SQL

puts "\nQuery:"
puts query
puts "\nResults:"
puts "-" * 80

result = adapter.read_data(query: query)
result.each do |row|
  puts row.inspect
end
