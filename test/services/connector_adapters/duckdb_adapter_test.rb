require "test_helper"

class ConnectorAdapters::DuckdbAdapterTest < ActiveSupport::TestCase
  setup do
    @adapter = ConnectorAdapters::DuckdbAdapter.new
  end

  teardown do
    @adapter&.close
  end

  test "initializes successfully" do
    assert_not_nil @adapter
    assert_not_nil @adapter.db
    assert_not_nil @adapter.connection
  end

  test "test_connection returns true" do
    assert @adapter.test_connection
  end

  # load_data tests
  test "load_data creates table and inserts data" do
    data = [
      { "id" => 1, "name" => "Alice", "age" => 30, "active" => true },
      { "id" => 2, "name" => "Bob", "age" => 25, "active" => false }
    ]

    rows_loaded = @adapter.load_data(table_name: "users", data: data)

    assert_equal 2, rows_loaded
    assert_includes @adapter.list_tables, "users"
  end

  test "load_data handles empty array" do
    rows_loaded = @adapter.load_data(table_name: "empty_table", data: [])
    assert_equal 0, rows_loaded
  end

  test "load_data infers correct types" do
    data = [
      {
        "int_col" => 42,
        "float_col" => 3.14,
        "string_col" => "test",
        "bool_col" => true,
        "date_col" => Date.today,
        "time_col" => Time.current
      }
    ]

    @adapter.load_data(table_name: "type_test", data: data)

    schema = @adapter.get_schema(table_name: "type_test")
    assert_equal 6, schema.size

    # Check that types are mapped correctly
    type_map = schema.each_with_object({}) { |col, hash| hash[col[:name]] = col[:type] }
    assert_equal "BIGINT", type_map["int_col"]
    assert_equal "DOUBLE", type_map["float_col"]
    assert_equal "VARCHAR", type_map["string_col"]
    assert_equal "BOOLEAN", type_map["bool_col"]
    assert_equal "DATE", type_map["date_col"]
    assert_match(/TIMESTAMP/, type_map["time_col"])
  end

  test "load_data handles large datasets in batches" do
    data = 2500.times.map do |i|
      { "id" => i, "value" => "row_#{i}" }
    end

    rows_loaded = @adapter.load_data(table_name: "large_table", data: data)
    assert_equal 2500, rows_loaded

    # Verify all data was loaded
    result = @adapter.execute_query(sql: "SELECT COUNT(*) as count FROM large_table")
    assert_equal 2500, result[:rows].first["count"]
  end

  test "load_data handles special characters in column names" do
    data = [
      { "Column Name" => "value1", "special@char" => "value2", "dash-name" => "value3" }
    ]

    rows_loaded = @adapter.load_data(table_name: "special_cols", data: data)
    assert_equal 1, rows_loaded
  end

  test "load_data handles null values" do
    data = [
      { "id" => 1, "name" => "Alice", "email" => nil },
      { "id" => 2, "name" => nil, "email" => "bob@example.com" }
    ]

    rows_loaded = @adapter.load_data(table_name: "nulls_table", data: data)
    assert_equal 2, rows_loaded

    result = @adapter.execute_query(sql: "SELECT * FROM nulls_table WHERE name IS NULL")
    assert_equal 1, result[:row_count]
  end

  # execute_query tests
  test "execute_query runs simple SELECT" do
    data = [
      { "id" => 1, "amount" => 100 },
      { "id" => 2, "amount" => 200 }
    ]
    @adapter.load_data(table_name: "transactions", data: data)

    result = @adapter.execute_query(sql: "SELECT * FROM transactions")

    assert_equal 2, result[:row_count]
    assert_equal 2, result[:rows].size
    assert result[:execution_time_ms] > 0
  end

  test "execute_query runs aggregation queries" do
    data = [
      { "category" => "A", "amount" => 100 },
      { "category" => "B", "amount" => 200 },
      { "category" => "A", "amount" => 150 }
    ]
    @adapter.load_data(table_name: "sales", data: data)

    result = @adapter.execute_query(
      sql: "SELECT category, SUM(amount) as total FROM sales GROUP BY category ORDER BY category"
    )

    assert_equal 2, result[:row_count]
    assert_equal "A", result[:rows].first["category"]
    assert_equal 250, result[:rows].first["total"]
  end

  test "execute_query runs JOIN queries across multiple tables" do
    users = [
      { "id" => 1, "name" => "Alice" },
      { "id" => 2, "name" => "Bob" }
    ]
    orders = [
      { "user_id" => 1, "amount" => 100 },
      { "user_id" => 1, "amount" => 150 },
      { "user_id" => 2, "amount" => 200 }
    ]

    @adapter.load_data(table_name: "users", data: users)
    @adapter.load_data(table_name: "orders", data: orders)

    result = @adapter.execute_query(
      sql: <<~SQL
        SELECT u.name, COUNT(*) as order_count, SUM(o.amount) as total
        FROM users u
        JOIN orders o ON u.id = o.user_id
        GROUP BY u.name
        ORDER BY u.name
      SQL
    )

    assert_equal 2, result[:row_count]
    alice_row = result[:rows].find { |r| r["name"] == "Alice" }
    assert_equal 2, alice_row["order_count"]
    assert_equal 250, alice_row["total"]
  end

  test "execute_query raises error on invalid SQL" do
    assert_raises(ConnectorAdapters::BaseAdapter::QueryError) do
      @adapter.execute_query(sql: "SELECT * FROM nonexistent_table")
    end
  end

  # export_table tests
  test "export_table returns all data" do
    data = [
      { "id" => 1, "value" => "a" },
      { "id" => 2, "value" => "b" },
      { "id" => 3, "value" => "c" }
    ]
    @adapter.load_data(table_name: "export_test", data: data)

    exported = @adapter.export_table(table_name: "export_test")

    assert_equal 3, exported.size
    assert_equal data.map { |d| d.stringify_keys }, exported.map(&:stringify_keys)
  end

  test "export_table raises error for nonexistent table" do
    assert_raises(ConnectorAdapters::DuckdbAdapter::DuckDBError) do
      @adapter.export_table(table_name: "does_not_exist")
    end
  end

  # list_tables tests
  test "list_tables returns created tables" do
    @adapter.load_data(table_name: "table1", data: [ { "id" => 1 } ])
    @adapter.load_data(table_name: "table2", data: [ { "id" => 2 } ])

    tables = @adapter.list_tables

    assert_includes tables, "table1"
    assert_includes tables, "table2"
  end

  # get_schema tests
  test "get_schema returns column information" do
    data = [ { "id" => 1, "name" => "test", "active" => true } ]
    @adapter.load_data(table_name: "schema_test", data: data)

    schema = @adapter.get_schema(table_name: "schema_test")

    assert_equal 3, schema.size
    column_names = schema.map { |col| col[:name] }
    assert_includes column_names, "id"
    assert_includes column_names, "name"
    assert_includes column_names, "active"
  end

  test "get_schema returns empty array for nil table name" do
    schema = @adapter.get_schema(table_name: nil)
    assert_equal [], schema
  end

  # close tests
  test "close disconnects properly" do
    adapter = ConnectorAdapters::DuckdbAdapter.new
    assert_nothing_raised do
      adapter.close
    end
  end

  # Error handling tests
  test "handles SQL injection attempts safely" do
    data = [ { "id" => 1, "value" => "'; DROP TABLE test; --" } ]

    assert_nothing_raised do
      @adapter.load_data(table_name: "injection_test", data: data)
      result = @adapter.export_table(table_name: "injection_test")
      assert_equal "'; DROP TABLE test; --", result.first["value"]
    end
  end

  test "handles unicode and emoji in data" do
    data = [
      { "id" => 1, "text" => "Hello 世界 🌍" },
      { "id" => 2, "text" => "Emoji test 🚀💡🎉" }
    ]

    @adapter.load_data(table_name: "unicode_test", data: data)
    result = @adapter.export_table(table_name: "unicode_test")

    assert_equal "Hello 世界 🌍", result.first["text"]
    assert_equal "Emoji test 🚀💡🎉", result.last["text"]
  end
end
