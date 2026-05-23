# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

if Rails.env.development?
  puts "Creating development users..."

  # Admin user
  User.find_or_create_by!(email: "admin@alice.example") do |user|
    user.name = "Admin User"
    user.password = "password123"
    user.password_confirmation = "password123"
    user.role = :admin
  end
  puts "  ✓ Admin user created (admin@alice.example / password123)"

  # Viewer user
  User.find_or_create_by!(email: "viewer@alice.example") do |user|
    user.name = "Viewer User"
    user.password = "password123"
    user.password_confirmation = "password123"
    user.role = :viewer
  end
  puts "  ✓ Viewer created (viewer@alice.example / password123)"

  # Connectors
  puts "\nCreating connectors..."

  prod_connector = Connector.find_or_create_by!(name: "Production Snowflake") do |connector|
    connector.connector_type = "snowflake"
    connector.config = {
      "account" => "your_account.us-east-1",
      "username" => "alice_user",
      "database" => "ANALYTICS_DB",
      "warehouse" => "COMPUTE_WH",
      "private_key" => "placeholder_private_key"
    }
    connector.status = :connected
  end
  puts "  ✓ Production Snowflake connector created"

  staging_connector = Connector.find_or_create_by!(name: "Staging Snowflake") do |connector|
    connector.connector_type = "snowflake"
    connector.config = {
      "account" => "your_account.us-east-1",
      "username" => "alice_staging",
      "database" => "STAGING_DB",
      "warehouse" => "DEV_WH",
      "private_key" => "placeholder_private_key"
    }
    connector.status = :connected
  end
  puts "  ✓ Staging Snowflake connector created"

  warehouse_connector = Connector.find_or_create_by!(name: "Data Warehouse") do |connector|
    connector.connector_type = "snowflake"
    connector.config = {
      "account" => "your_account.us-east-1",
      "username" => "warehouse_admin",
      "database" => "DW_DB",
      "warehouse" => "WAREHOUSE_WH",
      "private_key" => "placeholder_private_key"
    }
    connector.status = :connected
  end
  puts "  ✓ Data Warehouse connector created"

  crm_connector = Connector.find_or_create_by!(name: "CRM Database") do |connector|
    connector.connector_type = "snowflake"
    connector.config = {
      "account" => "your_account.us-east-1",
      "username" => "crm_user",
      "database" => "CRM_DB",
      "warehouse" => "CRM_WH",
      "private_key" => "placeholder_private_key"
    }
    connector.status = :connected
  end
  puts "  ✓ CRM Database connector created"

  # Datasets
  puts "\nCreating datasets..."

  sales_dataset = Dataset.find_or_create_by!(name: "Sales Summary") do |dataset|
    dataset.description = "Daily aggregated sales data for reporting and analytics"
    dataset.connector = prod_connector
    dataset.table_name = "sales_summary"
    dataset.schema_name = "PUBLIC"
    dataset.schema = {
      "columns" => [
        { "name" => "sale_date", "type" => "DATE" },
        { "name" => "product_category", "type" => "VARCHAR" },
        { "name" => "total_orders", "type" => "INTEGER" },
        { "name" => "total_revenue", "type" => "DECIMAL" }
      ]
    }
    dataset.status = :active
    dataset.row_count = 365
    dataset.last_updated_at = 1.day.ago
  end
  puts "  ✓ Sales Summary dataset created"

  customer_dataset = Dataset.find_or_create_by!(name: "Customer Analytics") do |dataset|
    dataset.description = "Customer behavior and segmentation data"
    dataset.connector = warehouse_connector
    dataset.table_name = "customer_analytics"
    dataset.schema_name = "PUBLIC"
    dataset.schema = {
      "columns" => [
        { "name" => "customer_id", "type" => "INTEGER" },
        { "name" => "segment", "type" => "VARCHAR" },
        { "name" => "lifetime_value", "type" => "DECIMAL" },
        { "name" => "last_purchase_date", "type" => "DATE" }
      ]
    }
    dataset.status = :active
    dataset.row_count = 15000
    dataset.last_updated_at = 2.hours.ago
  end
  puts "  ✓ Customer Analytics dataset created"

  # Pipelines
  puts "\nCreating pipelines..."

  # Pipeline 1: Single source pipeline using Dataset
  pipeline1 = Pipeline.find_by(name: "Daily Sales Summary")
  unless pipeline1
    pipeline1 = Pipeline.new(
      name: "Daily Sales Summary",
      description: "Aggregates daily sales data from production database",
      transformation_sql: <<~SQL,
        SELECT
          DATE(created_at) as sale_date,
          category,
          COUNT(*) as total_transactions,
          SUM(amount) as total_amount
        FROM sales_summary
        GROUP BY DATE(created_at), category
        ORDER BY sale_date DESC
      SQL
      destination_connector: warehouse_connector,
      write_disposition: :truncate_and_load,
      schedule: "0 2 * * *",  # Daily at 2 AM
      status: :idle
    )
    pipeline1.pipeline_sources.build(dataset: sales_dataset, table_alias: "sales_summary")
    pipeline1.save!
  end
  puts "  ✓ Daily Sales Summary pipeline created (single source using Dataset)"

  # Pipeline 2: Multi-source pipeline using multiple Datasets
  pipeline2 = Pipeline.find_by(name: "Unified Transaction Report")
  unless pipeline2
    pipeline2 = Pipeline.new(
      name: "Unified Transaction Report",
      description: "Combines sales and customer data from Datasets",
      transformation_sql: <<~SQL,
        WITH sales_data AS (
          SELECT#{' '}
            'sales' as source,
            sale_date as date,
            product_category as category,
            total_orders,
            total_revenue as amount
          FROM sales_summary
        ),
        customer_data AS (
          SELECT
            'customers' as source,
            last_purchase_date as date,
            segment as category,
            1 as total_orders,
            lifetime_value as amount
          FROM customer_analytics
        )
        SELECT#{' '}
          source,
          COUNT(*) as record_count,
          SUM(amount) as total_amount,
          AVG(amount) as avg_amount
        FROM (
          SELECT * FROM sales_data
          UNION ALL
          SELECT * FROM customer_data
        ) combined
        GROUP BY source
      SQL
      destination_connector: warehouse_connector,
      write_disposition: :append,
      schedule: "0 */6 * * *",  # Every 6 hours
      status: :idle
    )
    pipeline2.pipeline_sources.build(dataset: sales_dataset, table_alias: "sales_summary")
    pipeline2.pipeline_sources.build(dataset: customer_dataset, table_alias: "customer_analytics")
    pipeline2.save!
  end
  puts "  ✓ Unified Transaction Report pipeline created (multi-source using Datasets)"

  # Pipeline 3: Complex multi-source with JOINs using Datasets
  pipeline3 = Pipeline.find_by(name: "Category Performance Analysis")
  unless pipeline3
    pipeline3 = Pipeline.new(
      name: "Category Performance Analysis",
      description: "Joins sales and customer data from multiple Datasets",
      transformation_sql: <<~SQL,
        WITH sales_summary_agg AS (
          SELECT
            product_category as category,
            SUM(total_orders) as transaction_count,
            SUM(total_revenue) as total_amount,
            MAX(sale_date) as last_transaction
          FROM sales_summary
          GROUP BY product_category
        ),
        customer_summary AS (
          SELECT
            segment as category,
            COUNT(*) as customer_count,
            AVG(lifetime_value) as avg_customer_value
          FROM customer_analytics
          GROUP BY segment
        )
        SELECT
          s.category,
          COALESCE(s.transaction_count, 0) as total_orders,
          COALESCE(s.total_amount, 0) as total_revenue,
          COALESCE(c.customer_count, 0) as unique_customers,
          COALESCE(c.avg_customer_value, 0) as avg_ltv,
          s.last_transaction
        FROM sales_summary_agg s
        LEFT JOIN customer_summary c ON s.category = c.category
        ORDER BY total_revenue DESC
      SQL
      destination_connector: warehouse_connector,
      write_disposition: :truncate_and_load,
      schedule: "0 3 * * *",  # Daily at 3 AM
      status: :idle
    )
    pipeline3.pipeline_sources.build(dataset: sales_dataset, table_alias: "sales_summary")
    pipeline3.pipeline_sources.build(dataset: customer_dataset, table_alias: "customer_analytics")
    pipeline3.save!
  end
  puts "  ✓ Category Performance Analysis pipeline created (multi-source Datasets with JOIN)"

  # Pipeline 4: No destination (transformation only) using Dataset
  pipeline4 = Pipeline.find_by(name: "Data Quality Check")
  unless pipeline4
    pipeline4 = Pipeline.new(
      name: "Data Quality Check",
      description: "Validates data quality without writing to destination",
      transformation_sql: <<~SQL,
        SELECT
          'sales_summary' as source_table,
          COUNT(*) as total_rows,
          COUNT(DISTINCT sale_date) as unique_dates,
          COUNT(DISTINCT product_category) as unique_categories,
          SUM(CASE WHEN total_revenue <= 0 THEN 1 ELSE 0 END) as invalid_revenue,
          SUM(CASE WHEN product_category IS NULL THEN 1 ELSE 0 END) as null_categories,
          MIN(total_revenue) as min_revenue,
          MAX(total_revenue) as max_revenue,
          AVG(total_revenue) as avg_revenue
        FROM sales_summary
      SQL
      destination_connector: nil,
      schedule: "0 * * * *",  # Hourly
      status: :idle
    )
    pipeline4.pipeline_sources.build(dataset: sales_dataset, table_alias: "sales_summary")
    pipeline4.save!
  end
  puts "  ✓ Data Quality Check pipeline created (no destination using Dataset)"

  # Create some sample pipeline runs to show history
  puts "\nCreating sample pipeline run history..."

  # Successful run
  run1 = pipeline1.pipeline_runs.find_or_create_by!(started_at: 2.days.ago) do |run|
    run.status = :succeeded
    run.completed_at = 2.days.ago + 2.minutes
    run.logs = "Pipeline execution completed successfully\n\nSources loaded: 1\nTransformation rows: 1500\nExecution time: 1200ms\nDestination rows written: 1500\n\nCompleted at: #{run.completed_at}"
  end

  # Failed run
  run2 = pipeline2.pipeline_runs.find_or_create_by!(started_at: 1.day.ago) do |run|
    run.status = :failed
    run.completed_at = 1.day.ago + 30.seconds
    run.error_message = "Connection timeout"
    run.logs = "Pipeline execution failed\n\nError: Connection timeout\nError class: PipelineExecutionService::ExecutionError\n\nFailed at: #{run.completed_at}"
  end

  # Recent successful run
  run3 = pipeline1.pipeline_runs.find_or_create_by!(started_at: 3.hours.ago) do |run|
    run.status = :succeeded
    run.completed_at = 3.hours.ago + 90.seconds
    run.logs = "Pipeline execution completed successfully\n\nSources loaded: 1\nTransformation rows: 250\nExecution time: 900ms\nDestination rows written: 250\n\nCompleted at: #{run.completed_at}"
  end

  puts "  ✓ Sample pipeline runs created"

  # MRO (Maintenance, Repair, Operations) Connectors
  puts "\nCreating MRO connectors..."

  equipment_connector = Connector.find_or_create_by!(name: "Equipment Master") do |connector|
    connector.connector_type = "snowflake"
    connector.config = {
      "account" => "your_account.us-east-1",
      "username" => "mro_user",
      "database" => "MRO_DB",
      "warehouse" => "MRO_WH",
      "private_key" => "placeholder_private_key"
    }
    connector.status = :connected
  end
  puts "  ✓ Equipment Master connector created"

  work_orders_connector = Connector.find_or_create_by!(name: "Work Orders") do |connector|
    connector.connector_type = "snowflake"
    connector.config = {
      "account" => "your_account.us-east-1",
      "username" => "mro_user",
      "database" => "MRO_DB",
      "warehouse" => "MRO_WH",
      "private_key" => "placeholder_private_key"
    }
    connector.status = :connected
  end
  puts "  ✓ Work Orders connector created"

  parts_inventory_connector = Connector.find_or_create_by!(name: "Parts Inventory") do |connector|
    connector.connector_type = "snowflake"
    connector.config = {
      "account" => "your_account.us-east-1",
      "username" => "mro_user",
      "database" => "MRO_DB",
      "warehouse" => "MRO_WH",
      "private_key" => "placeholder_private_key"
    }
    connector.status = :connected
  end
  puts "  ✓ Parts Inventory connector created"

  maintenance_history_connector = Connector.find_or_create_by!(name: "Maintenance History") do |connector|
    connector.connector_type = "snowflake"
    connector.config = {
      "account" => "your_account.us-east-1",
      "username" => "mro_user",
      "database" => "MRO_DB",
      "warehouse" => "MRO_WH",
      "private_key" => "placeholder_private_key"
    }
    connector.status = :connected
  end
  puts "  ✓ Maintenance History connector created"

  # MRO Datasets
  puts "\nCreating MRO datasets..."

  equipment_dataset = Dataset.find_or_create_by!(name: "Equipment Master Data") do |dataset|
    dataset.description = "Master data for all equipment including aircraft, vehicles, and machinery"
    dataset.connector = equipment_connector
    dataset.table_name = "equipment_master"
    dataset.schema_name = "PUBLIC"
    dataset.schema = {
      "columns" => [
        { "name" => "equipment_id", "type" => "VARCHAR" },
        { "name" => "equipment_type", "type" => "VARCHAR" },
        { "name" => "model", "type" => "VARCHAR" },
        { "name" => "serial_number", "type" => "VARCHAR" },
        { "name" => "location", "type" => "VARCHAR" },
        { "name" => "status", "type" => "VARCHAR" },
        { "name" => "install_date", "type" => "DATE" },
        { "name" => "last_maintenance_date", "type" => "DATE" },
        { "name" => "operating_hours", "type" => "DECIMAL" }
      ]
    }
    dataset.status = :active
    dataset.row_count = 250
    dataset.last_updated_at = 1.hour.ago
  end
  puts "  ✓ Equipment Master Data dataset created"

  work_orders_dataset = Dataset.find_or_create_by!(name: "Work Orders Data") do |dataset|
    dataset.description = "Active and completed work orders for equipment maintenance"
    dataset.connector = work_orders_connector
    dataset.table_name = "work_orders"
    dataset.schema_name = "PUBLIC"
    dataset.schema = {
      "columns" => [
        { "name" => "wo_number", "type" => "VARCHAR" },
        { "name" => "equipment_id", "type" => "VARCHAR" },
        { "name" => "wo_type", "type" => "VARCHAR" },
        { "name" => "priority", "type" => "VARCHAR" },
        { "name" => "status", "type" => "VARCHAR" },
        { "name" => "assigned_technician", "type" => "VARCHAR" },
        { "name" => "created_date", "type" => "DATE" },
        { "name" => "scheduled_date", "type" => "DATE" },
        { "name" => "completed_date", "type" => "DATE" },
        { "name" => "labor_hours", "type" => "DECIMAL" },
        { "name" => "downtime_hours", "type" => "DECIMAL" },
        { "name" => "description", "type" => "VARCHAR" }
      ]
    }
    dataset.status = :active
    dataset.row_count = 1840
    dataset.last_updated_at = 30.minutes.ago
  end
  puts "  ✓ Work Orders Data dataset created"

  parts_dataset = Dataset.find_or_create_by!(name: "Parts Inventory") do |dataset|
    dataset.description = "Current parts inventory with quantities and costs"
    dataset.connector = parts_inventory_connector
    dataset.table_name = "parts_inventory"
    dataset.schema_name = "PUBLIC"
    dataset.schema = {
      "columns" => [
        { "name" => "part_number", "type" => "VARCHAR" },
        { "name" => "part_description", "type" => "VARCHAR" },
        { "name" => "category", "type" => "VARCHAR" },
        { "name" => "quantity_on_hand", "type" => "INTEGER" },
        { "name" => "reorder_point", "type" => "INTEGER" },
        { "name" => "unit_cost", "type" => "DECIMAL" },
        { "name" => "location_bin", "type" => "VARCHAR" },
        { "name" => "last_ordered_date", "type" => "DATE" }
      ]
    }
    dataset.status = :active
    dataset.row_count = 890
    dataset.last_updated_at = 2.hours.ago
  end
  puts "  ✓ Parts Inventory dataset created"

  # MRO Demo Pipelines
  puts "\nCreating MRO demo pipelines..."

  # Pipeline: Equipment Downtime Analysis using Dataset
  mro_pipeline1 = Pipeline.find_by(name: "Equipment Downtime Analysis")
  unless mro_pipeline1
    mro_pipeline1 = Pipeline.new(
      name: "Equipment Downtime Analysis",
      description: "Calculate total downtime hours by equipment type for the last 30 days",
      transformation_sql: <<~SQL,
        SELECT
          wo_type as equipment_type,
          COUNT(DISTINCT equipment_id) as affected_equipment,
          COUNT(*) as total_work_orders,
          SUM(downtime_hours) as total_downtime_hours,
          AVG(downtime_hours) as avg_downtime_per_wo,
          MAX(downtime_hours) as max_downtime_event
        FROM work_orders_data
        WHERE created_date >= CURRENT_DATE - 30
          AND downtime_hours > 0
        GROUP BY wo_type
        ORDER BY total_downtime_hours DESC
      SQL
      destination_connector: warehouse_connector,
      write_disposition: :truncate_and_load,
      schedule: "0 6 * * *",  # Daily at 6 AM
      status: :idle
    )
    mro_pipeline1.pipeline_sources.build(dataset: work_orders_dataset, table_alias: "work_orders_data")
    mro_pipeline1.save!
  end
  puts "  ✓ Equipment Downtime Analysis pipeline created (using Dataset)"

  # Pipeline: Work Order Completion Rate using Dataset
  mro_pipeline2 = Pipeline.find_by(name: "Work Order Completion Rate")
  unless mro_pipeline2
    mro_pipeline2 = Pipeline.new(
      name: "Work Order Completion Rate",
      description: "Track work order completion rates by technician and priority",
      transformation_sql: <<~SQL,
        SELECT
          assigned_technician,
          priority,
          COUNT(*) as total_work_orders,
          SUM(CASE WHEN status = 'Completed' THEN 1 ELSE 0 END) as completed,
          SUM(CASE WHEN status IN ('Open', 'In Progress') THEN 1 ELSE 0 END) as in_progress,
          SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) as cancelled,
          ROUND(100.0 * SUM(CASE WHEN status = 'Completed' THEN 1 ELSE 0 END) / COUNT(*), 2) as completion_rate,
          AVG(CASE WHEN status = 'Completed' THEN labor_hours END) as avg_labor_hours
        FROM work_orders_data
        WHERE created_date >= CURRENT_DATE - 90
        GROUP BY assigned_technician, priority
        ORDER BY assigned_technician, priority
      SQL
      destination_dataset: sales_dataset,
      write_disposition: :truncate_and_load,
      schedule: "0 7 * * *",  # Daily at 7 AM
      status: :idle
    )
    mro_pipeline2.pipeline_sources.build(dataset: work_orders_dataset, table_alias: "work_orders_data")
    mro_pipeline2.save!
  end
  puts "  ✓ Work Order Completion Rate pipeline created (using Dataset)"

  # Pipeline: Parts Consumption Trends using Dataset
  mro_pipeline3 = Pipeline.find_by(name: "Parts Consumption Trends")
  unless mro_pipeline3
    mro_pipeline3 = Pipeline.new(
      name: "Parts Consumption Trends",
      description: "Analyze parts usage patterns and identify fast-moving items",
      transformation_sql: <<~SQL,
        SELECT
          category,
          COUNT(DISTINCT part_number) as unique_parts,
          SUM(quantity_on_hand) as total_quantity,
          AVG(unit_cost) as avg_unit_cost,
          SUM(quantity_on_hand * unit_cost) as total_inventory_value,
          SUM(CASE WHEN quantity_on_hand <= reorder_point THEN 1 ELSE 0 END) as parts_below_reorder,
          MIN(last_ordered_date) as oldest_order_date,
          MAX(last_ordered_date) as most_recent_order_date
        FROM parts_inventory_data
        GROUP BY category
        ORDER BY total_inventory_value DESC
      SQL
      destination_connector: warehouse_connector,
      write_disposition: :append,
      schedule: "0 8 * * 1",  # Weekly on Monday at 8 AM
      status: :idle
    )
    mro_pipeline3.pipeline_sources.build(dataset: parts_dataset, table_alias: "parts_inventory_data")
    mro_pipeline3.save!
  end
  puts "  ✓ Parts Consumption Trends pipeline created (using Dataset)"

  # Pipeline: Overdue Maintenance Alerts using Datasets
  mro_pipeline4 = Pipeline.find_by(name: "Overdue Maintenance Alerts")
  unless mro_pipeline4
    mro_pipeline4 = Pipeline.new(
      name: "Overdue Maintenance Alerts",
      description: "Identify equipment with overdue scheduled maintenance",
      transformation_sql: <<~SQL,
        WITH scheduled_maintenance AS (
          SELECT
            equipment_id,
            scheduled_date,
            wo_type,
            priority,
            status
          FROM work_orders_data
          WHERE wo_type IN ('Preventive Maintenance', 'Scheduled Inspection')
            AND status NOT IN ('Completed', 'Cancelled')
            AND scheduled_date < CURRENT_DATE
        )
        SELECT
          e.equipment_id,
          e.equipment_type,
          e.model,
          e.location,
          e.operating_hours,
          COUNT(sm.equipment_id) as overdue_maintenance_count,
          MIN(sm.scheduled_date) as oldest_overdue_date,
          MAX(sm.priority) as highest_priority,
          DATEDIFF('day', MIN(sm.scheduled_date), CURRENT_DATE) as days_overdue
        FROM equipment_master_data e
        INNER JOIN scheduled_maintenance sm ON e.equipment_id = sm.equipment_id
        WHERE e.status = 'Active'
        GROUP BY e.equipment_id, e.equipment_type, e.model, e.location, e.operating_hours
        HAVING COUNT(sm.equipment_id) > 0
        ORDER BY days_overdue DESC, highest_priority
      SQL
      destination_dataset: customer_dataset,
      write_disposition: :truncate_and_load,
      schedule: "0 5 * * *",  # Daily at 5 AM
      status: :idle
    )
    mro_pipeline4.pipeline_sources.build(dataset: work_orders_dataset, table_alias: "work_orders_data")
    mro_pipeline4.pipeline_sources.build(dataset: equipment_dataset, table_alias: "equipment_master_data")
    mro_pipeline4.save!
  end
  puts "  ✓ Overdue Maintenance Alerts pipeline created (using Datasets)"

  # Visual Mode Demo Pipelines (for sales demonstrations)
  puts "\nCreating Visual Mode demo pipelines..."

  # Demo 1: Simple Equipment List (Visual Mode) using Dataset
  demo1 = Pipeline.find_by(name: "[DEMO] Equipment List")
  unless demo1
    demo1 = Pipeline.new(
      name: "[DEMO] Equipment List",
      description: "Simple column selection demo - shows all equipment with key details",
      transformation_mode: "visual",
      transformation_config: {
        "version" => "1.0",
        "sources" => [{ "type" => "dataset", "id" => equipment_dataset.id, "alias" => "equipment" }],
        "columns" => [
          { "type" => "source_column", "source" => "equipment", "name" => "equipment_id" },
          { "type" => "source_column", "source" => "equipment", "name" => "equipment_type" },
          { "type" => "source_column", "source" => "equipment", "name" => "model" },
          { "type" => "source_column", "source" => "equipment", "name" => "location" },
          { "type" => "source_column", "source" => "equipment", "name" => "status" }
        ],
        "filters" => [],
        "groupBy" => [],
        "orderBy" => [{ "column" => "equipment_type", "direction" => "ASC" }],
        "limit" => nil
      },
      destination_dataset: sales_dataset,
      write_disposition: :truncate_and_load,
      schedule: "0 8 * * *",
      status: :idle
    )
    # Generate SQL from config
    demo1.regenerate_sql!
    demo1.pipeline_sources.build(dataset: equipment_dataset, table_alias: "equipment")
    demo1.save!
  end
  puts "  ✓ [DEMO] Equipment List (visual mode using Dataset)"

  # Demo 2: Filtered Work Orders (Visual Mode with Filters) using Dataset
  demo2 = Pipeline.find_by(name: "[DEMO] High Priority Work Orders")
  unless demo2
    demo2 = Pipeline.new(
      name: "[DEMO] High Priority Work Orders",
      description: "Filter demo - shows only high priority completed work orders",
      transformation_mode: "visual",
      transformation_config: {
        "version" => "1.0",
        "sources" => [{ "type" => "dataset", "id" => work_orders_dataset.id, "alias" => "work_orders" }],
        "columns" => [
          { "type" => "source_column", "source" => "work_orders", "name" => "wo_number" },
          { "type" => "source_column", "source" => "work_orders", "name" => "equipment_id" },
          { "type" => "source_column", "source" => "work_orders", "name" => "priority" },
          { "type" => "source_column", "source" => "work_orders", "name" => "status" },
          { "type" => "source_column", "source" => "work_orders", "name" => "assigned_technician" },
          { "type" => "source_column", "source" => "work_orders", "name" => "labor_hours" }
        ],
        "filters" => [
          { "column" => { "source" => "work_orders", "name" => "priority" }, "operator" => "=", "value" => "High" },
          { "column" => { "source" => "work_orders", "name" => "status" }, "operator" => "=", "value" => "Completed" }
        ],
        "groupBy" => [],
        "orderBy" => [{ "column" => "labor_hours", "direction" => "DESC" }],
        "limit" => nil
      },
      destination_dataset: customer_dataset,
      write_disposition: :truncate_and_load,
      schedule: "0 9 * * *",
      status: :idle
    )
    demo2.regenerate_sql!
    demo2.pipeline_sources.build(dataset: work_orders_dataset, table_alias: "work_orders")
    demo2.save!
  end
  puts "  ✓ [DEMO] High Priority Work Orders (visual mode with filters using Dataset)"

  # Demo 3: Aggregated Equipment Downtime (Visual Mode with GROUP BY) using Dataset
  demo3 = Pipeline.find_by(name: "[DEMO] Downtime by Equipment Type")
  unless demo3
    demo3 = Pipeline.new(
      name: "[DEMO] Downtime by Equipment Type",
      description: "Aggregation demo - groups work orders by equipment type and sums downtime",
      transformation_mode: "visual",
      transformation_config: {
        "version" => "1.0",
        "sources" => [{ "type" => "dataset", "id" => work_orders_dataset.id, "alias" => "work_orders" }],
        "columns" => [
          { "type" => "source_column", "source" => "work_orders", "name" => "wo_type" },
          { "type" => "aggregation", "function" => "COUNT", "column" => { "source" => "work_orders", "name" => "wo_number" }, "alias" => "total_work_orders" },
          { "type" => "aggregation", "function" => "SUM", "column" => { "source" => "work_orders", "name" => "downtime_hours" }, "alias" => "total_downtime" },
          { "type" => "aggregation", "function" => "AVG", "column" => { "source" => "work_orders", "name" => "downtime_hours" }, "alias" => "avg_downtime" }
        ],
        "filters" => [
          { "column" => { "source" => "work_orders", "name" => "downtime_hours" }, "operator" => ">", "value" => 0 }
        ],
        "groupBy" => [
          { "source" => "work_orders", "name" => "wo_type" }
        ],
        "orderBy" => [{ "column" => "total_downtime", "direction" => "DESC" }],
        "limit" => 10
      },
      destination_connector: warehouse_connector,
      write_disposition: :truncate_and_load,
      schedule: "0 6 * * *",
      status: :idle
    )
    demo3.regenerate_sql!
    demo3.pipeline_sources.build(dataset: work_orders_dataset, table_alias: "work_orders")
    demo3.save!
  end
  puts "  ✓ [DEMO] Downtime by Equipment Type (visual mode with aggregation using Dataset)"

  puts "\n✅ Development seed data created successfully!"
  puts "\n📊 MRO Demo Pipelines:"
  puts "   - Equipment Downtime Analysis (single source aggregation)"
  puts "   - Work Order Completion Rate (grouped by technician + priority)"
  puts "   - Parts Consumption Trends (inventory analysis)"
  puts "   - Overdue Maintenance Alerts (multi-source with JOIN)"
  puts "\n🎯 Visual Mode Sales Demos:"
  puts "   - [DEMO] Equipment List (simple column selection)"
  puts "   - [DEMO] High Priority Work Orders (filters)"
  puts "   - [DEMO] Downtime by Equipment Type (aggregation + GROUP BY)"
end
