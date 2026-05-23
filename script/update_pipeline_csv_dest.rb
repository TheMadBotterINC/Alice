#!/usr/bin/env ruby
# Update Manufacturing Employment Trends pipeline to use CSV output

p = Pipeline.find_by(name: 'Manufacturing Employment Trends')
dataset = Dataset.find_by(name: 'Manufacturing Employment CSV Output')

p.update!(destination_dataset_id: dataset.id)

puts "✓ Pipeline updated with CSV file destination"
puts ""
puts "Pipeline: #{p.name}"
puts "Destination: #{p.destination_dataset.name}"
puts "Output file: data/output/manufacturing_employment_analysis.csv"
