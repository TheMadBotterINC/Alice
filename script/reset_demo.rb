#!/usr/bin/env ruby
# Reset demo environment for next sales call

require_relative '../config/environment'

puts "Resetting Demo Environment..."
puts "=" * 60

# Delete all demo pipelines and their runs
puts "\n🧹 Cleaning demo pipelines..."
demo_pipelines = Pipeline.where("name LIKE ?", "[DEMO]%")
run_count = demo_pipelines.sum { |p| p.pipeline_runs.count }
demo_pipelines.destroy_all
puts "✓ Deleted #{demo_pipelines.count} demo pipelines and #{run_count} pipeline runs"

# Clean up old demo CSV files from tmp/
puts "\n🗑️  Cleaning old demo files..."
csv_pattern = Rails.root.join('tmp', '*demo*.csv')
csv_count = Dir.glob(csv_pattern).count
FileUtils.rm_f(Dir.glob(csv_pattern))
puts "✓ Deleted #{csv_count} old CSV files" if csv_count > 0

# Keep connector and datasets, just clean pipeline history
puts "\n📋 Keeping datasets and connector..."
connector = Connector.find_by(name: "MRO Demo Database")
if connector
  datasets = Dataset.where(connector: connector)
  puts "✓ Preserved connector: #{connector.name}"
  puts "✓ Preserved datasets: #{datasets.pluck(:name).join(', ')}"
else
  puts "⚠️  No demo connector found - run seed_demo_data.rb first"
end

puts "\n" + "=" * 60
puts "✅ Demo environment reset!"
puts "\nReady for next demo:"
puts "  - All demo pipelines cleared"
puts "  - Connector and datasets preserved"
puts "  - Data intact and ready to query"
puts "\nTo create fresh pipelines:"
puts "  1. Go to Pipelines → Visual Query Builder"
puts "  2. Select datasets: 'Demo Work Orders', 'Demo Parts Inventory', 'Demo Equipment Master'"
puts "  3. Build your demo query live on the call"
