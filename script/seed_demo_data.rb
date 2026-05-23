#!/usr/bin/env ruby
# Seed demo data into local DuckDB for sales demonstrations

require_relative '../config/environment'

puts "Seeding MRO Demo Data..."
puts "=" * 60

# Check if CSV files exist
required_files = [
  'demo_data/work_orders.csv',
  'demo_data/parts_inventory.csv',
  'demo_data/equipment_master.csv'
]

missing_files = required_files.reject { |f| File.exist?(f) }
if missing_files.any?
  puts "❌ Missing required data files:"
  missing_files.each { |f| puts "   - #{f}" }
  puts "\nPlease run: ruby script/generate_demo_data.rb"
  exit 1
end

# Clean up existing demo data
puts "\n🧹 Cleaning existing demo data..."
Pipeline.where("name LIKE ?", "[DEMO]%").destroy_all
Dataset.where("name LIKE ?", "%Demo%").destroy_all
Connector.where("name LIKE ?", "%MRO Demo%").destroy_all

# Create DuckDB connector
puts "\n📊 Creating DuckDB connector..."
demo_connector = Connector.find_or_initialize_by(name: "MRO Demo Database")
demo_connector.assign_attributes(
  connector_type: "duckdb",
  config: {
    database_path: Rails.root.join('storage', 'demo_mro.duckdb').to_s
  },
  status: :connected,
  last_checked_at: Time.current
)
demo_connector.save!
puts "✓ Created connector: #{demo_connector.name}"

# Initialize DuckDB and load CSV data
puts "\n📥 Loading CSV data into DuckDB..."
db = DuckDB::Database.open(demo_connector.config['database_path'])
conn = db.connect

# Load work orders
conn.execute("DROP TABLE IF EXISTS work_orders")
conn.execute(<<~SQL)
  CREATE TABLE work_orders AS 
  SELECT * FROM read_csv_auto('demo_data/work_orders.csv', 
    header=true, 
    dateformat='%Y-%m-%d'
  )
SQL
work_orders_count = conn.query("SELECT COUNT(*) as count FROM work_orders").first[0]
puts "✓ Loaded #{work_orders_count} work orders"

# Load parts inventory
conn.execute("DROP TABLE IF EXISTS parts_inventory")
conn.execute(<<~SQL)
  CREATE TABLE parts_inventory AS 
  SELECT * FROM read_csv_auto('demo_data/parts_inventory.csv',
    header=true,
    dateformat='%Y-%m-%d'
  )
SQL
parts_count = conn.query("SELECT COUNT(*) as count FROM parts_inventory").first[0]
puts "✓ Loaded #{parts_count} parts"

# Load equipment master
conn.execute("DROP TABLE IF EXISTS equipment_master")
conn.execute(<<~SQL)
  CREATE TABLE equipment_master AS 
  SELECT * FROM read_csv_auto('demo_data/equipment_master.csv',
    header=true,
    dateformat='%Y-%m-%d'
  )
SQL
equipment_count = conn.query("SELECT COUNT(*) as count FROM equipment_master").first[0]
puts "✓ Loaded #{equipment_count} equipment records"

conn.disconnect
db.close

# Create Datasets
puts "\n📋 Creating Datasets..."

work_orders_dataset = Dataset.create!(
  name: "Demo Work Orders",
  description: "Work order history for MRO demo - includes corrective and preventive maintenance",
  connector: demo_connector,
  table_name: "work_orders",
  schema_name: "main",
  schema: {
    "columns" => [
      { "name" => "wo_number", "type" => "VARCHAR" },
      { "name" => "equipment_id", "type" => "VARCHAR" },
      { "name" => "equipment_type", "type" => "VARCHAR" },
      { "name" => "wo_type", "type" => "VARCHAR" },
      { "name" => "status", "type" => "VARCHAR" },
      { "name" => "created_date", "type" => "DATE" },
      { "name" => "scheduled_date", "type" => "DATE" },
      { "name" => "completed_date", "type" => "DATE" },
      { "name" => "assigned_technician", "type" => "VARCHAR" },
      { "name" => "downtime_hours", "type" => "DOUBLE" },
      { "name" => "labor_hours", "type" => "DOUBLE" },
      { "name" => "part_number", "type" => "VARCHAR" },
      { "name" => "priority", "type" => "VARCHAR" },
      { "name" => "description", "type" => "VARCHAR" }
    ]
  },
  status: :active,
  row_count: work_orders_count,
  last_updated_at: Time.current
)
puts "✓ Created dataset: #{work_orders_dataset.name}"

parts_dataset = Dataset.create!(
  name: "Demo Parts Inventory",
  description: "Parts inventory master for MRO demo - includes stock levels and costs",
  connector: demo_connector,
  table_name: "parts_inventory",
  schema_name: "main",
  schema: {
    "columns" => [
      { "name" => "part_number", "type" => "VARCHAR" },
      { "name" => "part_description", "type" => "VARCHAR" },
      { "name" => "category", "type" => "VARCHAR" },
      { "name" => "quantity_on_hand", "type" => "INTEGER" },
      { "name" => "reorder_point", "type" => "INTEGER" },
      { "name" => "unit_cost", "type" => "DOUBLE" },
      { "name" => "location_bin", "type" => "VARCHAR" },
      { "name" => "last_ordered_date", "type" => "DATE" }
    ]
  },
  status: :active,
  row_count: parts_count,
  last_updated_at: Time.current
)
puts "✓ Created dataset: #{parts_dataset.name}"

equipment_dataset = Dataset.create!(
  name: "Demo Equipment Master",
  description: "Equipment master data for MRO demo - all facility assets",
  connector: demo_connector,
  table_name: "equipment_master",
  schema_name: "main",
  schema: {
    "columns" => [
      { "name" => "equipment_id", "type" => "VARCHAR" },
      { "name" => "equipment_type", "type" => "VARCHAR" },
      { "name" => "model", "type" => "VARCHAR" },
      { "name" => "serial_number", "type" => "VARCHAR" },
      { "name" => "location", "type" => "VARCHAR" },
      { "name" => "status", "type" => "VARCHAR" },
      { "name" => "install_date", "type" => "DATE" },
      { "name" => "last_maintenance_date", "type" => "DATE" },
      { "name" => "operating_hours", "type" => "DOUBLE" }
    ]
  },
  status: :active,
  row_count: equipment_count,
  last_updated_at: Time.current
)
puts "✓ Created dataset: #{equipment_dataset.name}"

puts "\n" + "=" * 60
puts "✅ Demo seeding complete!"
puts "\nCreated:"
puts "  - 1 DuckDB connector: #{demo_connector.name}"
puts "  - 3 datasets: Work Orders, Parts Inventory, Equipment Master"
puts "  - #{work_orders_count + parts_count + equipment_count} total rows"
puts "\nReady for sales demos! 🚀"
puts "\nNext steps:"
puts "  1. Create pipelines in Visual Query Builder"
puts "  2. Use datasets: 'Demo Work Orders', 'Demo Parts Inventory', 'Demo Equipment Master'"
puts "  3. Run: ruby script/reset_demo.rb to clean slate between demos"
