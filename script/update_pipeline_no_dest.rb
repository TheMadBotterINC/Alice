#!/usr/bin/env ruby
# Remove destination from pipeline to test transformation only

p = Pipeline.find_by(name: 'Manufacturing Employment Trends')

if p.nil?
  puts "Pipeline not found!"
  exit 1
end

p.update!(destination_connector_id: nil)
puts "Pipeline updated - destination removed for transformation-only testing"
puts "Pipeline: #{p.name}"
puts "Source connectors: #{p.source_connectors.map(&:name).join(', ')}"
puts "Destination: #{p.destination_connector&.name || 'NONE (transformation only)'}"
