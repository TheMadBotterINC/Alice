#!/usr/bin/env ruby
# Update pipeline SQL to properly cast DATE column

p = Pipeline.find_by(name: 'Manufacturing Employment Trends')

if p.nil?
  puts "Pipeline not found!"
  exit 1
end

new_sql = <<~SQL.squish
  SELECT#{' '}
    VARIABLE,#{' '}
    VARIABLE_NAME,#{' '}
    CAST(DATE AS INTEGER) as date_code,
    CAST(VALUE AS DOUBLE) as value
  FROM snowflake_public_data_test_2#{' '}
  WHERE VARIABLE_NAME LIKE '%Manufacturing%'
  ORDER BY date_code DESC, value DESC#{' '}
  LIMIT 100
SQL

p.update!(transformation_sql: new_sql)
puts "Pipeline SQL updated successfully!"
puts "New SQL:"
puts new_sql
