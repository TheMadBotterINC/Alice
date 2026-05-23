# frozen_string_literal: true

require "test_helper"

class TransformationConfigServiceTest < ActiveSupport::TestCase
  test "converts simple SELECT with single column" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "work_orders" }],
      columns: [
        { type: "source_column", source: "work_orders", name: "wo_number" }
      ]
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "SELECT"
    assert_includes sql, "work_orders.wo_number"
    assert_includes sql, "FROM work_orders"
  end

  test "converts SELECT with multiple columns" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "equipment" }],
      columns: [
        { type: "source_column", source: "equipment", name: "equipment_id" },
        { type: "source_column", source: "equipment", name: "equipment_type" },
        { type: "source_column", source: "equipment", name: "location" }
      ]
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "equipment.equipment_id"
    assert_includes sql, "equipment.equipment_type"
    assert_includes sql, "equipment.location"
  end

  test "converts SELECT with column aliases" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "work_orders" }],
      columns: [
        { type: "source_column", source: "work_orders", name: "wo_number", alias: "work_order_id" },
        { type: "source_column", source: "work_orders", name: "status", alias: "current_status" }
      ]
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "work_orders.wo_number AS work_order_id"
    assert_includes sql, "work_orders.status AS current_status"
  end

  test "converts SELECT with COUNT aggregation" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "work_orders" }],
      columns: [
        { type: "source_column", source: "work_orders", name: "equipment_type" },
        { type: "aggregation", function: "COUNT", column: { source: "work_orders", name: "id" }, alias: "total_orders" }
      ],
      groupBy: [{ source: "work_orders", name: "equipment_type" }]
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "COUNT(work_orders.id) AS total_orders"
    assert_includes sql, "GROUP BY work_orders.equipment_type"
  end

  test "converts SELECT with SUM aggregation" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "work_orders" }],
      columns: [
        { type: "aggregation", function: "SUM", column: { source: "work_orders", name: "downtime_hours" }, alias: "total_downtime" }
      ]
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "SUM(work_orders.downtime_hours) AS total_downtime"
  end

  test "converts SELECT with AVG, MIN, MAX aggregations" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "parts" }],
      columns: [
        { type: "aggregation", function: "AVG", column: { source: "parts", name: "unit_cost" }, alias: "avg_cost" },
        { type: "aggregation", function: "MIN", column: { source: "parts", name: "unit_cost" }, alias: "min_cost" },
        { type: "aggregation", function: "MAX", column: { source: "parts", name: "unit_cost" }, alias: "max_cost" }
      ]
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "AVG(parts.unit_cost) AS avg_cost"
    assert_includes sql, "MIN(parts.unit_cost) AS min_cost"
    assert_includes sql, "MAX(parts.unit_cost) AS max_cost"
  end

  test "converts SELECT with COUNT(DISTINCT)" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "work_orders" }],
      columns: [
        { type: "aggregation", function: "COUNT_DISTINCT", column: { source: "work_orders", name: "equipment_id" }, alias: "unique_equipment" }
      ]
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "COUNT(DISTINCT work_orders.equipment_id) AS unique_equipment"
  end

  test "supports 'aggregate' column type (alternative to 'aggregation')" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "work_orders" }],
      columns: [
        { type: "source_column", source: "work_orders", name: "equipment_type" },
        { type: "aggregate", function: "SUM", column: { source: "work_orders", name: "downtime_hours" }, alias: "total_downtime" }
      ],
      groupBy: [{ source: "work_orders", name: "equipment_type" }]
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "SUM(work_orders.downtime_hours) AS total_downtime"
    assert_includes sql, "GROUP BY work_orders.equipment_type"
  end

  test "converts WHERE with equals filter" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "work_orders" }],
      columns: [{ type: "source_column", source: "work_orders", name: "wo_number" }],
      filters: [{ column: { source: "work_orders", name: "status" }, operator: "=", value: "Completed" }]
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "WHERE work_orders.status = 'Completed'"
  end

  test "converts WHERE with multiple filters (AND)" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "work_orders" }],
      columns: [{ type: "source_column", source: "work_orders", name: "wo_number" }],
      filters: [
        { column: { source: "work_orders", name: "status" }, operator: "=", value: "Completed" },
        { column: { source: "work_orders", name: "priority" }, operator: "=", value: "High" }
      ]
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "WHERE work_orders.status = 'Completed'"
    assert_includes sql, "AND work_orders.priority = 'High'"
  end

  test "converts WHERE with numeric comparison operators" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "work_orders" }],
      columns: [{ type: "source_column", source: "work_orders", name: "wo_number" }],
      filters: [
        { column: { source: "work_orders", name: "downtime_hours" }, operator: ">", value: 5 }
      ]
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "WHERE work_orders.downtime_hours > 5"
  end

  test "converts WHERE with LIKE operator" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "equipment" }],
      columns: [{ type: "source_column", source: "equipment", name: "equipment_id" }],
      filters: [{ column: { source: "equipment", name: "model" }, operator: "LIKE", value: "%Boeing%" }]
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "WHERE equipment.model LIKE '%Boeing%'"
  end

  test "converts WHERE with IN operator" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "work_orders" }],
      columns: [{ type: "source_column", source: "work_orders", name: "wo_number" }],
      filters: [{ column: { source: "work_orders", name: "priority" }, operator: "IN", value: ["High", "Critical"] }]
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "WHERE work_orders.priority IN ('High', 'Critical')"
  end

  test "converts WHERE with BETWEEN operator" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "work_orders" }],
      columns: [{ type: "source_column", source: "work_orders", name: "wo_number" }],
      filters: [{ column: { source: "work_orders", name: "labor_hours" }, operator: "BETWEEN", value: [1, 10] }]
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "WHERE work_orders.labor_hours BETWEEN 1 AND 10"
  end

  test "converts WHERE with IS NULL operator" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "work_orders" }],
      columns: [{ type: "source_column", source: "work_orders", name: "wo_number" }],
      filters: [{ column: { source: "work_orders", name: "completed_date" }, operator: "IS_NULL" }]
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "WHERE work_orders.completed_date IS NULL"
  end

  test "converts WHERE with SQL expression value (CURRENT_DATE)" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "work_orders" }],
      columns: [{ type: "source_column", source: "work_orders", name: "wo_number" }],
      filters: [{ column: { source: "work_orders", name: "created_date" }, operator: ">=", value: "CURRENT_DATE - 30" }]
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "WHERE work_orders.created_date >= CURRENT_DATE - 30"
  end

  test "converts GROUP BY with single column" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "work_orders" }],
      columns: [
        { type: "source_column", source: "work_orders", name: "equipment_type" },
        { type: "aggregation", function: "COUNT", column: { source: "work_orders", name: "id" }, alias: "total" }
      ],
      groupBy: [{ source: "work_orders", name: "equipment_type" }]
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "GROUP BY work_orders.equipment_type"
  end

  test "converts GROUP BY with multiple columns" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "work_orders" }],
      columns: [
        { type: "source_column", source: "work_orders", name: "equipment_type" },
        { type: "source_column", source: "work_orders", name: "priority" },
        { type: "aggregation", function: "COUNT", column: { source: "work_orders", name: "id" }, alias: "total" }
      ],
      groupBy: [
        { source: "work_orders", name: "equipment_type" },
        { source: "work_orders", name: "priority" }
      ]
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "GROUP BY work_orders.equipment_type, work_orders.priority"
  end

  test "converts ORDER BY with single column" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "work_orders" }],
      columns: [{ type: "source_column", source: "work_orders", name: "wo_number" }],
      orderBy: [{ column: "wo_number", direction: "ASC" }]
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "ORDER BY wo_number ASC"
  end

  test "converts ORDER BY with multiple columns" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "work_orders" }],
      columns: [
        { type: "source_column", source: "work_orders", name: "priority" },
        { type: "source_column", source: "work_orders", name: "created_date" }
      ],
      orderBy: [
        { column: "priority", direction: "DESC" },
        { column: "created_date", direction: "ASC" }
      ]
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "ORDER BY priority DESC, created_date ASC"
  end

  test "converts LIMIT clause" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "work_orders" }],
      columns: [{ type: "source_column", source: "work_orders", name: "wo_number" }],
      limit: 100
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "LIMIT 100"
  end

  test "converts complete query with all clauses" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "work_orders" }],
      columns: [
        { type: "source_column", source: "work_orders", name: "equipment_type" },
        { type: "aggregation", function: "COUNT", column: { source: "work_orders", name: "id" }, alias: "total_orders" },
        { type: "aggregation", function: "SUM", column: { source: "work_orders", name: "downtime_hours" }, alias: "total_downtime" }
      ],
      filters: [
        { column: { source: "work_orders", name: "status" }, operator: "=", value: "Completed" }
      ],
      groupBy: [{ source: "work_orders", name: "equipment_type" }],
      orderBy: [{ column: "total_downtime", direction: "DESC" }],
      limit: 10
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "SELECT"
    assert_includes sql, "FROM work_orders"
    assert_includes sql, "WHERE work_orders.status = 'Completed'"
    assert_includes sql, "GROUP BY work_orders.equipment_type"
    assert_includes sql, "ORDER BY total_downtime DESC"
    assert_includes sql, "LIMIT 10"
  end

  test "sanitizes identifiers with special characters" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "my-source" }],
      columns: [{ type: "source_column", source: "my-source", name: "column-name" }]
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "my_source.column_name"
    assert_includes sql, "FROM my_source"
  end

  test "sanitizes identifiers starting with numbers" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "123_table" }],
      columns: [{ type: "source_column", source: "123_table", name: "456_column" }]
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "_123_table._456_column"
  end

  test "properly escapes single quotes in string values" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "work_orders" }],
      columns: [{ type: "source_column", source: "work_orders", name: "description" }],
      filters: [{ column: { source: "work_orders", name: "description" }, operator: "LIKE", value: "O'Reilly%" }]
    }

    service = TransformationConfigService.new(config)
    sql = service.to_sql

    assert_includes sql, "O''Reilly%"
  end

  test "validates missing required keys" do
    config = { version: "1.0" }

    service = TransformationConfigService.new(config)
    
    error = assert_raises TransformationConfigService::ConfigurationError do
      service.validate_config!
    end
    
    assert_includes error.message, "Missing required key: sources"
  end

  test "validates empty sources array" do
    config = {
      version: "1.0",
      sources: [],
      columns: [{ type: "source_column", source: "test", name: "col" }]
    }

    service = TransformationConfigService.new(config)
    
    error = assert_raises TransformationConfigService::ConfigurationError do
      service.validate_config!
    end
    
    assert_includes error.message, "At least one source is required"
  end

  test "validates empty columns array" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "test" }],
      columns: []
    }

    service = TransformationConfigService.new(config)
    
    error = assert_raises TransformationConfigService::ConfigurationError do
      service.validate_config!
    end
    
    assert_includes error.message, "At least one column is required"
  end

  test "validates unsupported aggregation function" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "work_orders" }],
      columns: [
        { type: "aggregation", function: "MEDIAN", column: { source: "work_orders", name: "value" }, alias: "median_value" }
      ]
    }

    service = TransformationConfigService.new(config)
    
    error = assert_raises TransformationConfigService::ConfigurationError do
      service.to_sql
    end
    
    assert_includes error.message, "Unsupported aggregation function: MEDIAN"
  end

  test "validates unsupported operator" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "work_orders" }],
      columns: [{ type: "source_column", source: "work_orders", name: "col" }],
      filters: [{ column: { source: "work_orders", name: "value" }, operator: "REGEX", value: ".*" }]
    }

    service = TransformationConfigService.new(config)
    
    error = assert_raises TransformationConfigService::ConfigurationError do
      service.validate_config!
    end
    
    assert_includes error.message, "Unsupported operator: REGEX"
  end

  test "validates invalid LIMIT value" do
    config = {
      version: "1.0",
      sources: [{ type: "connector", id: 1, alias: "work_orders" }],
      columns: [{ type: "source_column", source: "work_orders", name: "col" }],
      limit: -10
    }

    service = TransformationConfigService.new(config)
    
    error = assert_raises TransformationConfigService::ConfigurationError do
      service.to_sql
    end
    
    assert_includes error.message, "LIMIT must be a positive integer"
  end

  test "handles JSON string input" do
    json_config = '{"version":"1.0","sources":[{"type":"connector","id":1,"alias":"test"}],"columns":[{"type":"source_column","source":"test","name":"col"}]}'

    service = TransformationConfigService.new(json_config)
    sql = service.to_sql

    assert_includes sql, "SELECT"
    assert_includes sql, "FROM test"
  end
end
