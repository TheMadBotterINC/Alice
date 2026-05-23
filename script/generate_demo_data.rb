#!/usr/bin/env ruby
# Generate realistic MRO demo data for sales demonstrations

require 'csv'
require 'date'
require 'fileutils'

# Ensure demo_data directory exists
FileUtils.mkdir_p('demo_data')

puts "Generating MRO Demo Data..."
puts "=" * 60

# Configuration
NUM_WORK_ORDERS = 1800
NUM_PARTS = 900
START_DATE = Date.today - 180  # 6 months of history
END_DATE = Date.today

# Reference data
EQUIPMENT_TYPES = [
  "Centrifugal Pump", "Hydraulic Pump", "Air Compressor", "Conveyor Belt",
  "HVAC System", "Hydraulic Press", "Electric Motor", "Robotic Arm",
  "Storage Tank", "Cooling Tower", "Gearbox", "Blower", "Mixer",
  "Forklift", "Crane", "Boiler", "Chiller"
]

WO_TYPES = ["Corrective", "Preventive", "Scheduled Inspection", "Emergency"]
STATUSES = ["Completed", "In Progress", "Scheduled", "Open", "Cancelled"]
PRIORITIES = ["Critical", "High", "Medium", "Low"]
TECHNICIANS = [
  "Mike Thompson", "Sarah Chen", "John Martinez", "Lisa Anderson",
  "David Kim", "Maria Garcia", "Robert Johnson", "Emily Davis",
  "James Wilson", "Jennifer Lee"
]

PART_CATEGORIES = [
  "Seals", "Filters", "Bearings", "Belts", "Valves", "Motors",
  "Cylinders", "Hoses", "Pumps", "Impellers", "Thermostats",
  "Compressors", "Servos", "Encoders", "Fans", "Coils"
]

# Part descriptions by category
PART_DESCRIPTIONS = {
  "Seals" => ["Mechanical Seal - Type A", "O-Ring Set", "Shaft Seal Kit", "Face Seal Assembly"],
  "Filters" => ["Hydraulic Filter 10 Micron", "Air Filter Element", "Oil Filter Cartridge", "Fuel Filter"],
  "Bearings" => ["Roller Bearing 6205", "Ball Bearing SKF", "Thrust Bearing", "Pillow Block Bearing"],
  "Belts" => ["V-Belt A-Section", "Timing Belt", "Flat Belt 6in", "Serpentine Belt"],
  "Valves" => ["Pressure Relief Valve", "Check Valve 2in", "Solenoid Valve 24V", "Ball Valve 1/2in"],
  "Motors" => ["AC Motor 5HP", "DC Motor 3HP", "Servo Motor", "Stepper Motor"],
  "Cylinders" => ["Hydraulic Cylinder 4in", "Pneumatic Cylinder", "Tie-Rod Cylinder", "Welded Cylinder"],
  "Hoses" => ["Hydraulic Hose 1/2in", "Air Hose 50ft", "Water Hose", "Chemical Transfer Hose"],
  "Pumps" => ["Centrifugal Pump 3HP", "Gear Pump", "Diaphragm Pump", "Submersible Pump"],
  "Impellers" => ["Pump Impeller 6in", "Closed Impeller", "Open Impeller", "Semi-Open Impeller"],
  "Thermostats" => ["Digital Thermostat", "Programmable Thermostat", "Wireless Thermostat", "Analog Thermostat"],
  "Compressors" => ["Scroll Compressor", "Rotary Compressor", "Reciprocating Compressor", "Screw Compressor"],
  "Servos" => ["Servo Motor 2kW", "Servo Drive", "Servo Controller", "Servo Gearbox"],
  "Encoders" => ["Rotary Encoder", "Linear Encoder", "Absolute Encoder", "Incremental Encoder"],
  "Fans" => ["Axial Fan 24in", "Centrifugal Fan", "Exhaust Fan", "Cooling Fan"],
  "Coils" => ["Evaporator Coil", "Condenser Coil", "Heating Coil", "Cooling Coil"]
}

# Generate Parts Inventory
puts "\n📦 Generating Parts Inventory (#{NUM_PARTS} parts)..."

parts = []
part_numbers_used = []

NUM_PARTS.times do |i|
  category = PART_CATEGORIES.sample
  descriptions = PART_DESCRIPTIONS[category]
  description = descriptions.sample
  
  # Generate part number
  category_prefix = category[0..2].upcase
  part_number = "#{category_prefix}-#{(i + 100).to_s.rjust(3, '0')}"
  part_numbers_used << part_number
  
  # Random inventory levels
  reorder_point = rand(5..20)
  quantity_on_hand = rand(0..30)
  
  # Unit cost based on category complexity
  base_costs = {
    "Seals" => 200, "Filters" => 50, "Bearings" => 100, "Belts" => 75,
    "Valves" => 150, "Motors" => 500, "Cylinders" => 800, "Hoses" => 60,
    "Pumps" => 1200, "Impellers" => 300, "Thermostats" => 180,
    "Compressors" => 2500, "Servos" => 1800, "Encoders" => 900,
    "Fans" => 350, "Coils" => 450
  }
  unit_cost = base_costs[category] * (0.7 + rand * 0.6) # ±30% variance
  
  # Location in warehouse
  aisle = ('A'..'F').to_a.sample
  rack = rand(1..20).to_s.rjust(2, '0')
  level = ('A'..'D').to_a.sample
  location_bin = "#{aisle}-#{rack}-#{level}"
  
  # Last ordered date (some recent, some old)
  last_ordered = if rand < 0.7
    START_DATE + rand(0..(END_DATE - START_DATE).to_i)
  else
    nil
  end
  
  parts << {
    part_number: part_number,
    part_description: description,
    category: category,
    quantity_on_hand: quantity_on_hand,
    reorder_point: reorder_point,
    unit_cost: unit_cost.round(2),
    location_bin: location_bin,
    last_ordered_date: last_ordered
  }
end

# Write parts inventory CSV
CSV.open('demo_data/parts_inventory.csv', 'w') do |csv|
  csv << [:part_number, :part_description, :category, :quantity_on_hand, 
          :reorder_point, :unit_cost, :location_bin, :last_ordered_date]
  parts.each do |part|
    csv << part.values
  end
end

puts "✓ Generated #{parts.count} parts"
puts "  - #{parts.count { |p| p[:quantity_on_hand] <= p[:reorder_point] }} parts below reorder point"
puts "  - Average cost: $#{(parts.sum { |p| p[:unit_cost] } / parts.count).round(2)}"

# Generate Equipment Master
puts "\n🏭 Generating Equipment Master..."

equipment = []
equipment_ids = []

100.times do |i|
  equipment_type = EQUIPMENT_TYPES.sample
  type_prefix = equipment_type.split.map { |w| w[0] }.join.upcase
  equipment_id = "#{type_prefix}-#{(i + 1).to_s.rjust(3, '0')}"
  equipment_ids << equipment_id
  
  install_date = START_DATE - rand(365..2555) # 1-7 years old
  last_maintenance = START_DATE + rand(0..(END_DATE - START_DATE).to_i)
  operating_hours = rand(1000..50000.0).round(1)
  
  equipment << {
    equipment_id: equipment_id,
    equipment_type: equipment_type,
    model: "Model-#{rand(100..999)}",
    serial_number: "SN-#{rand(100000..999999)}",
    location: ["Building A", "Building B", "Warehouse", "Production Floor", "Yard"].sample,
    status: rand < 0.95 ? "Active" : "Inactive",
    install_date: install_date,
    last_maintenance_date: last_maintenance,
    operating_hours: operating_hours
  }
end

CSV.open('demo_data/equipment_master.csv', 'w') do |csv|
  csv << [:equipment_id, :equipment_type, :model, :serial_number, :location, 
          :status, :install_date, :last_maintenance_date, :operating_hours]
  equipment.each do |eq|
    csv << eq.values
  end
end

puts "✓ Generated #{equipment.count} equipment records"

# Generate Work Orders
puts "\n🔧 Generating Work Orders (#{NUM_WORK_ORDERS} records)..."

work_orders = []

NUM_WORK_ORDERS.times do |i|
  wo_number = "WO-#{(24000 + i).to_s.rjust(5, '0')}"
  
  # Date logic
  created_date = START_DATE + rand(0..(END_DATE - START_DATE).to_i)
  scheduled_date = created_date + rand(1..5)
  
  # Status determines completion (weighted random)
  status = if created_date < END_DATE - 7
    # Older work orders: mostly completed
    rand_val = rand
    if rand_val < 0.7
      "Completed"
    elsif rand_val < 0.8
      "In Progress"
    elsif rand_val < 0.85
      "Scheduled"
    elsif rand_val < 0.95
      "Open"
    else
      "Cancelled"
    end
  else
    # Recent work orders more likely to be in progress/scheduled
    rand_val = rand
    if rand_val < 0.3
      "Completed"
    elsif rand_val < 0.6
      "In Progress"
    elsif rand_val < 0.8
      "Scheduled"
    elsif rand_val < 0.95
      "Open"
    else
      "Cancelled"
    end
  end
  
  completed_date = if status == "Completed"
    scheduled_date + rand(0..3)
  else
    nil
  end
  
  # Work order type and equipment (weighted random)
  wo_type_rand = rand
  wo_type = if wo_type_rand < 0.4
    "Corrective"
  elsif wo_type_rand < 0.85
    "Preventive"
  elsif wo_type_rand < 0.95
    "Scheduled Inspection"
  else
    "Emergency"
  end
  
  equipment_id = equipment_ids.sample
  equipment_type = equipment.find { |e| e[:equipment_id] == equipment_id }&.fetch(:equipment_type) || EQUIPMENT_TYPES.sample
  
  # Preventive maintenance has no downtime, corrective does
  if wo_type == "Preventive" || wo_type == "Scheduled Inspection"
    downtime_hours = 0.0
    # Priority for preventive (weighted: low priority more common)
    priority_rand = rand
    priority = if priority_rand < 0.05
      "Critical"
    elsif priority_rand < 0.2
      "High"
    elsif priority_rand < 0.7
      "Medium"
    else
      "Low"
    end
  else
    # Downtime for corrective work (70% have downtime)
    downtime_hours = rand < 0.7 ? rand(1.0..20.0).round(1) : 0.0
    # Priority for corrective (weighted: higher priority more common)
    priority_rand = rand
    priority = if priority_rand < 0.2
      "Critical"
    elsif priority_rand < 0.5
      "High"
    elsif priority_rand < 0.85
      "Medium"
    else
      "Low"
    end
  end
  
  # Labor hours
  labor_hours = if status == "Completed"
    (downtime_hours * 1.3 + rand(1.0..5.0)).round(1)
  else
    nil
  end
  
  # Part used (60% of corrective work orders, 30% of preventive)
  part_number = if wo_type == "Corrective" && rand < 0.6
    part_numbers_used.sample
  elsif wo_type == "Preventive" && rand < 0.3
    part_numbers_used.sample
  else
    nil
  end
  
  technician = TECHNICIANS.sample
  
  # Generate realistic description
  descriptions = if wo_type == "Preventive"
    [
      "Quarterly PM - filters and oil change",
      "Monthly filter replacement",
      "Weekly lubrication and inspection",
      "Annual inspection and coating check",
      "Quarterly maintenance cycle",
      "Monthly calibration check",
      "Routine maintenance and inspection"
    ]
  else
    [
      "Replace mechanical seal - excessive leaking",
      "Main drive bearing failure - emergency repair",
      "Pressure relief valve replacement",
      "Seal leaking - parts ordered",
      "Hydraulic cylinder failure - production down",
      "Bearing seizure - replacement required",
      "Motor overheating - thermal relay replaced",
      "Multiple seal failures - contamination issue",
      "Unloader valve failure - compressor cycling",
      "Belt tracking issue - alignment needed"
    ]
  end
  description = descriptions.sample
  
  work_orders << {
    wo_number: wo_number,
    equipment_id: equipment_id,
    equipment_type: equipment_type,
    wo_type: wo_type,
    status: status,
    created_date: created_date,
    scheduled_date: scheduled_date,
    completed_date: completed_date,
    assigned_technician: technician,
    downtime_hours: downtime_hours,
    labor_hours: labor_hours,
    part_number: part_number,
    priority: priority,
    description: description
  }
end

# Sort by created date descending (most recent first)
work_orders.sort_by! { |wo| -wo[:created_date].to_time.to_i }

CSV.open('demo_data/work_orders.csv', 'w') do |csv|
  csv << [:wo_number, :equipment_id, :equipment_type, :wo_type, :status,
          :created_date, :scheduled_date, :completed_date, :assigned_technician,
          :downtime_hours, :labor_hours, :part_number, :priority, :description]
  work_orders.each do |wo|
    csv << wo.values
  end
end

completed_count = work_orders.count { |wo| wo[:status] == "Completed" }
corrective_count = work_orders.count { |wo| wo[:wo_type] == "Corrective" }
preventive_count = work_orders.count { |wo| wo[:wo_type] == "Preventive" }
avg_downtime = work_orders.select { |wo| wo[:downtime_hours] > 0 }.map { |wo| wo[:downtime_hours] }.sum / work_orders.count.to_f

puts "✓ Generated #{work_orders.count} work orders"
puts "  - #{completed_count} completed (#{(completed_count * 100.0 / work_orders.count).round(1)}%)"
puts "  - #{corrective_count} corrective, #{preventive_count} preventive"
puts "  - Average downtime: #{avg_downtime.round(2)} hours"
puts "  - Date range: #{work_orders.last[:created_date]} to #{work_orders.first[:created_date]}"

puts "\n" + "=" * 60
puts "✅ Demo data generation complete!"
puts "\nFiles created:"
puts "  - demo_data/work_orders.csv (#{NUM_WORK_ORDERS} records)"
puts "  - demo_data/parts_inventory.csv (#{NUM_PARTS} records)"
puts "  - demo_data/equipment_master.csv (#{equipment.count} records)"
puts "\nReady for demo seeding!"
