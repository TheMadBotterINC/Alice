# MRO Demo Data Setup

This directory contains sample data and scripts for running smooth MRO sales demonstrations.

## Quick Start

```bash
# Step 1: Generate the CSV files (1,800 work orders, 900 parts, 100 equipment)
ruby script/generate_demo_data.rb

# Step 2: Load into DuckDB and create datasets
ruby script/seed_demo_data.rb

# Step 3: Between demos, reset to clean state
ruby script/reset_demo.rb
```

## What Gets Created

### CSV Files (demo_data/)
- `work_orders.csv` - 1,800 work orders (6 months of history)
- `parts_inventory.csv` - 900 parts with stock levels and costs
- `equipment_master.csv` - 100 pieces of equipment

### Database (storage/demo_mro.duckdb)
- Local DuckDB database with all three tables loaded
- Fast queries (< 1 second for demos)
- Zero network dependencies

### Alice Objects
- **Connector**: "MRO Demo Database" (DuckDB)
- **Datasets**:
  - Demo Work Orders
  - Demo Parts Inventory
  - Demo Equipment Master

## Demo Data Characteristics

### Work Orders
- **Date Range**: Last 6 months
- **Equipment Types**: Pumps, Compressors, Motors, Conveyors, HVAC, Presses, Robots, etc.
- **WO Types**: 40% Corrective, 45% Preventive, 10% Inspections, 5% Emergency
- **Status Mix**: 70% Completed, 10% In Progress, 5% Scheduled, 10% Open, 5% Cancelled
- **Downtime**: Corrective orders have 1-20 hours downtime, Preventive have 0
- **Parts Used**: 60% of corrective, 30% of preventive reference parts
- **Technicians**: 10 realistic names rotating assignments

### Parts Inventory
- **Categories**: Seals, Filters, Bearings, Belts, Valves, Motors, Cylinders, etc.
- **Stock Levels**: ~30% below reorder point (creates demo urgency)
- **Costs**: Realistic pricing $50-$2,500 depending on category
- **Locations**: Warehouse bins (A-12-C format)

### Equipment Master
- **Asset Types**: 17 different equipment types
- **Install Dates**: 1-7 years old
- **Operating Hours**: 1,000-50,000 hours
- **Status**: 95% Active, 5% Inactive

## Usage

### For Demo 1: Weekly Downtime Report
```ruby
# Uses: Demo Work Orders dataset
# Query: Downtime by equipment_type, last 7 days
# Filter: created_date > CURRENT_DATE - 7
# Group by: equipment_type
# Sort by: SUM(downtime_hours) DESC
```

### For Demo 2: Parts Reorder Alert
```ruby
# Uses: Demo Parts Inventory + Demo Work Orders datasets
# Join: parts.part_number = work_orders.part_number
# Filter: quantity_on_hand <= reorder_point
# Filter: created_date >= CURRENT_DATE - 30
# Result: Parts low on stock that are actively used
```

## Regenerating Data

To create fresh data with different random values:

```bash
# Delete old data
rm demo_data/*.csv
rm storage/demo_mro.duckdb

# Generate new data
ruby script/generate_demo_data.rb
ruby script/seed_demo_data.rb
```

## File Sizes

- work_orders.csv: ~350 KB
- parts_inventory.csv: ~90 KB  
- equipment_master.csv: ~10 KB
- demo_mro.duckdb: ~500 KB

All files are small and load instantly.

## Troubleshooting

### "Missing required data files"
Run `ruby script/generate_demo_data.rb` first to create CSVs.

### "DuckDB connection error"
Ensure the `duckdb` gem is installed: `bundle install`

### "Slow queries"
The local DuckDB should be instant. If slow:
- Check you're using "MRO Demo Database" connector (not Snowflake)
- Ensure dataset row_limit is not set too high
- Try: `rm storage/demo_mro.duckdb` and re-seed

### "Datasets not showing in Visual Query Builder"
- Verify datasets exist: `Dataset.where("name LIKE ?", "Demo%").pluck(:name)`
- Check connector status: `Connector.find_by(name: "MRO Demo Database").status`
- Refresh browser page

## Best Practices

1. **Before Each Demo**:
   - Run `ruby script/reset_demo.rb` to clear old pipelines
   - Test one quick query to ensure data loads fast
   - Have browser open and logged in

2. **During Demo**:
   - Use datasets named "Demo Work Orders" etc. (clearly demo data)
   - Build pipelines live, don't pre-create them
   - Name pipelines starting with "[DEMO]" for easy cleanup

3. **After Demo**:
   - Screenshots of good results for follow-up
   - Run `ruby script/reset_demo.rb` before next call

## Support

Questions? Check:
- `docs/mro_sales_demos.md` - Full demo scripts
- This README - Data setup
- `script/*.rb` - Script source code
