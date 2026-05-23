#!/usr/bin/env ruby
# Seed pre-fabbed demo pipelines for MRO demonstration
# Run after: ruby script/seed_demo_data.rb

require_relative '../config/environment'

puts "Creating Demo Pipelines..."
puts "=" * 60

# Find demo connector and datasets
demo_connector = Connector.find_by(name: "MRO Demo Database")
unless demo_connector
  puts "❌ Demo connector not found. Please run: ruby script/seed_demo_data.rb first"
  exit 1
end

work_orders_dataset = Dataset.find_by(name: "Demo Work Orders")
parts_dataset = Dataset.find_by(name: "Demo Parts Inventory")
equipment_dataset = Dataset.find_by(name: "Demo Equipment Master")

unless work_orders_dataset && parts_dataset && equipment_dataset
  puts "❌ Demo datasets not found. Please run: ruby script/seed_demo_data.rb first"
  exit 1
end

puts "\n📋 Found demo datasets:"
puts "  ✓ #{work_orders_dataset.name} (#{work_orders_dataset.row_count} rows)"
puts "  ✓ #{parts_dataset.name} (#{parts_dataset.row_count} rows)"
puts "  ✓ #{equipment_dataset.name} (#{equipment_dataset.row_count} rows)"

# Clean up existing demo pipelines
puts "\n🧹 Cleaning existing demo pipelines..."
Pipeline.where("name LIKE ?", "[DEMO]%").destroy_all

# Pipeline 1: Basic Work Order Analysis
puts "\n📊 Creating pipeline: Work Order Analysis..."
pipeline1 = Pipeline.new(
  name: "[DEMO] Work Order Analysis",
  description: "Analyze work order trends by type, status, and priority",
  transformation_sql: <<~SQL.strip,
    SELECT
      wo_type,
      status,
      priority,
      COUNT(*) as total_orders,
      AVG(downtime_hours) as avg_downtime,
      AVG(labor_hours) as avg_labor_hours,
      COUNT(DISTINCT equipment_id) as equipment_count
    FROM work_orders
    WHERE status IN ('Completed', 'In Progress', 'Scheduled')
    GROUP BY wo_type, status, priority
    ORDER BY total_orders DESC
  SQL
  write_disposition: :truncate_and_load,
  export_format: "csv",
  export_options: { "has_header" => true, "delimiter" => "," },
  status: :idle
)
pipeline1.pipeline_sources.build(dataset: work_orders_dataset, table_alias: "work_orders")
pipeline1.save!
puts "  ✓ Created: #{pipeline1.name}"

# Pipeline 2: Equipment Maintenance History
puts "\n📊 Creating pipeline: Equipment Maintenance History..."
pipeline2 = Pipeline.new(
  name: "[DEMO] Equipment Maintenance History",
  description: "Join equipment master with work orders to show maintenance history",
  transformation_sql: <<~SQL.strip,
    SELECT
      e.equipment_id,
      e.equipment_type,
      e.location,
      e.status as equipment_status,
      COUNT(w.wo_number) as total_work_orders,
      SUM(w.downtime_hours) as total_downtime,
      SUM(w.labor_hours) as total_labor_hours,
      MAX(w.completed_date) as last_maintenance_date,
      DATEDIFF('day', MAX(w.completed_date), CURRENT_DATE) as days_since_last_maintenance
    FROM equipment_master e
    LEFT JOIN work_orders w ON e.equipment_id = w.equipment_id
    GROUP BY e.equipment_id, e.equipment_type, e.location, e.status
    ORDER BY total_downtime DESC
  SQL
  write_disposition: :truncate_and_load,
  export_format: "csv",
  export_options: { "has_header" => true, "delimiter" => "," },
  status: :idle
)
pipeline2.pipeline_sources.build(dataset: equipment_dataset, table_alias: "equipment_master")
pipeline2.pipeline_sources.build(dataset: work_orders_dataset, table_alias: "work_orders")
pipeline2.save!
puts "  ✓ Created: #{pipeline2.name}"

# Pipeline 3: Parts Usage and Cost Analysis
puts "\n📊 Creating pipeline: Parts Usage and Cost..."
pipeline3 = Pipeline.new(
  name: "[DEMO] Parts Usage and Cost",
  description: "Analyze parts consumption and costs across work orders",
  transformation_sql: <<~SQL.strip,
    SELECT
      p.part_number,
      p.part_description,
      p.category,
      p.unit_cost,
      p.quantity_on_hand,
      COUNT(w.wo_number) as times_used,
      COUNT(DISTINCT w.equipment_id) as equipment_using_part,
      (p.unit_cost * COUNT(w.wo_number)) as estimated_total_cost,
      CASE
        WHEN p.quantity_on_hand < p.reorder_point THEN 'Low Stock'
        WHEN p.quantity_on_hand < (p.reorder_point * 1.5) THEN 'Monitor'
        ELSE 'Adequate'
      END as inventory_status
    FROM parts_inventory p
    LEFT JOIN work_orders w ON p.part_number = w.part_number
    GROUP BY p.part_number, p.part_description, p.category, p.unit_cost, p.quantity_on_hand, p.reorder_point
    ORDER BY times_used DESC, estimated_total_cost DESC
  SQL
  write_disposition: :truncate_and_load,
  export_format: "csv",
  export_options: { "has_header" => true, "delimiter" => "," },
  status: :idle
)
pipeline3.pipeline_sources.build(dataset: parts_dataset, table_alias: "parts_inventory")
pipeline3.pipeline_sources.build(dataset: work_orders_dataset, table_alias: "work_orders")
pipeline3.save!
puts "  ✓ Created: #{pipeline3.name}"

# Pipeline 4: Preventive vs Corrective Maintenance KPIs
puts "\n📊 Creating pipeline: Maintenance KPIs..."
pipeline4 = Pipeline.new(
  name: "[DEMO] Preventive vs Corrective KPIs",
  description: "Compare preventive and corrective maintenance efficiency",
  transformation_sql: <<~SQL.strip,
    SELECT
      wo_type,
      COUNT(*) as total_orders,
      COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () as percentage_of_total,
      AVG(downtime_hours) as avg_downtime,
      AVG(labor_hours) as avg_labor_hours,
      SUM(downtime_hours) as total_downtime,
      SUM(labor_hours) as total_labor_hours,
      AVG(DATEDIFF('day', scheduled_date, completed_date)) as avg_completion_days,
      COUNT(CASE WHEN priority = 'Emergency' THEN 1 END) as emergency_count
    FROM work_orders
    WHERE status = 'Completed'
      AND wo_type IN ('Preventive', 'Corrective')
    GROUP BY wo_type
  SQL
  write_disposition: :truncate_and_load,
  export_format: "csv",
  export_options: { "has_header" => true, "delimiter" => "," },
  status: :idle
)
pipeline4.pipeline_sources.build(dataset: work_orders_dataset, table_alias: "work_orders")
pipeline4.save!
puts "  ✓ Created: #{pipeline4.name}"

# Pipeline 5: High-Impact Equipment Report
puts "\n📊 Creating pipeline: High-Impact Equipment..."
pipeline5 = Pipeline.new(
  name: "[DEMO] High-Impact Equipment Report",
  description: "Identify equipment with highest downtime and maintenance costs",
  transformation_sql: <<~SQL.strip,
    WITH equipment_metrics AS (
      SELECT
        w.equipment_id,
        e.equipment_type,
        e.location,
        COUNT(w.wo_number) as work_order_count,
        SUM(w.downtime_hours) as total_downtime,
        SUM(w.labor_hours) as total_labor_hours,
        COUNT(CASE WHEN w.wo_type = 'Corrective' THEN 1 END) as corrective_count,
        COUNT(CASE WHEN w.priority = 'Emergency' THEN 1 END) as emergency_count
      FROM work_orders w
      LEFT JOIN equipment_master e ON w.equipment_id = e.equipment_id
      WHERE w.status = 'Completed'
      GROUP BY w.equipment_id, e.equipment_type, e.location
    )
    SELECT
      equipment_id,
      equipment_type,
      location,
      work_order_count,
      total_downtime,
      total_labor_hours,
      corrective_count,
      emergency_count,
      ROUND(corrective_count * 100.0 / NULLIF(work_order_count, 0), 1) as corrective_percentage,
      ROUND(total_downtime / NULLIF(work_order_count, 0), 2) as avg_downtime_per_wo
    FROM equipment_metrics
    WHERE total_downtime > 0
    ORDER BY total_downtime DESC
    LIMIT 25
  SQL
  write_disposition: :truncate_and_load,
  export_format: "csv",
  export_options: { "has_header" => true, "delimiter" => "," },
  status: :idle
)
pipeline5.pipeline_sources.build(dataset: work_orders_dataset, table_alias: "work_orders")
pipeline5.pipeline_sources.build(dataset: equipment_dataset, table_alias: "equipment_master")
pipeline5.save!
puts "  ✓ Created: #{pipeline5.name}"

# Pipeline 6: Technician Performance
puts "\n📊 Creating pipeline: Technician Performance..."
pipeline6 = Pipeline.new(
  name: "[DEMO] Technician Performance",
  description: "Analyze technician workload and efficiency metrics",
  transformation_sql: <<~SQL.strip,
    SELECT
      assigned_technician,
      COUNT(*) as total_assignments,
      COUNT(CASE WHEN status = 'Completed' THEN 1 END) as completed_count,
      COUNT(CASE WHEN status IN ('In Progress', 'Scheduled') THEN 1 END) as active_count,
      AVG(labor_hours) as avg_labor_hours,
      SUM(labor_hours) as total_labor_hours,
      AVG(CASE
        WHEN status = 'Completed'
        THEN DATEDIFF('day', scheduled_date, completed_date)
      END) as avg_completion_days,
      COUNT(CASE WHEN wo_type = 'Preventive' THEN 1 END) as preventive_count,
      COUNT(CASE WHEN wo_type = 'Corrective' THEN 1 END) as corrective_count
    FROM work_orders
    WHERE assigned_technician IS NOT NULL
    GROUP BY assigned_technician
    ORDER BY total_assignments DESC
  SQL
  write_disposition: :truncate_and_load,
  export_format: "csv",
  export_options: { "has_header" => true, "delimiter" => "," },
  status: :idle
)
pipeline6.pipeline_sources.build(dataset: work_orders_dataset, table_alias: "work_orders")
pipeline6.save!
puts "  ✓ Created: #{pipeline6.name}"

puts "\n" + "=" * 60
puts "✅ Demo pipelines created!"
puts "\nCreated #{Pipeline.where("name LIKE ?", "[DEMO]%").count} demo pipelines:"
Pipeline.where("name LIKE ?", "[DEMO]%").order(:name).each do |p|
  puts "  • #{p.name}"
  puts "    #{p.description}"
  puts "    Sources: #{p.source_datasets.pluck(:name).join(', ')}"
  puts ""
end

puts "Ready to demo! 🚀"
puts "\nNext steps:"
puts "  1. Start demo mode: bin/demo"
puts "  2. Navigate to: http://localhost:3000/pipelines"
puts "  3. Click 'Run' on any demo pipeline to show live results"
puts "  4. Edit pipelines to demonstrate Visual Query Builder"
