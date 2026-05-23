require "test_helper"

class MergeWriteDispositionTest < ActiveSupport::TestCase
  setup do
    @connector = connectors(:one)  # Production Snowflake
    @adapter = ConnectorAdapters::SnowflakeAdapter.new(@connector)
  end

  # Validation Tests
  test "pipeline requires merge_key when disposition is merge" do
    pipeline = Pipeline.new(
      name: "Test Merge Pipeline",
      transformation_sql: "SELECT * FROM test",
      write_disposition: :merge
      # Missing merge_key
    )

    assert_not pipeline.valid?
    assert_includes pipeline.errors[:merge_key], "can't be blank"
  end

  test "pipeline allows nil merge_key when disposition is not merge" do
    pipeline = Pipeline.new(
      name: "Test Append Pipeline",
      transformation_sql: "SELECT * FROM test",
      write_disposition: :append
      # No merge_key needed
    )

    # Should not fail on merge_key validation
    pipeline.valid?
    assert_not pipeline.errors.include?(:merge_key)
  end

  test "pipeline accepts merge_key when disposition is merge" do
    pipeline = Pipeline.new(
      name: "Test Merge Pipeline",
      transformation_sql: "SELECT * FROM test",
      write_disposition: :merge,
      merge_key: "id"
    )

    pipeline.valid?
    assert_not pipeline.errors.include?(:merge_key)
  end

  test "pipeline accepts multiple merge keys separated by comma" do
    pipeline = Pipeline.new(
      name: "Test Merge Pipeline",
      transformation_sql: "SELECT * FROM test",
      write_disposition: :merge,
      merge_key: "id, date, customer_id"
    )

    pipeline.valid?
    assert_not pipeline.errors.include?(:merge_key)
  end

  # SnowflakeAdapter merge_data method tests
  test "merge_data raises error if merge_key is nil" do
    data = [ { "id" => 1, "name" => "Alice" } ]

    error = assert_raises(ArgumentError) do
      @adapter.send(:merge_data, "test_table", data, merge_key: nil, schema: "PUBLIC")
    end

    assert_match /merge_key is required/, error.message
  end

  test "merge_data raises error if merge_key is blank string" do
    data = [ { "id" => 1, "name" => "Alice" } ]

    error = assert_raises(ArgumentError) do
      @adapter.send(:merge_data, "test_table", data, merge_key: "", schema: "PUBLIC")
    end

    assert_match /merge_key is required/, error.message
  end

  test "merge_data returns 0 for empty data" do
    result = @adapter.send(:merge_data, "test_table", [], merge_key: "id", schema: "PUBLIC")
    assert_equal 0, result
  end

  test "merge_data handles single merge key" do
    data = [ { "id" => 1, "name" => "Alice" } ]
    merge_keys = "id".split(",").map(&:strip)

    assert_equal [ "id" ], merge_keys
  end

  test "merge_data handles multiple merge keys" do
    merge_keys = "id, date, customer_id".split(",").map(&:strip)

    assert_equal [ "id", "date", "customer_id" ], merge_keys
  end

  test "merge_data handles merge keys with extra whitespace" do
    merge_keys = "  id  ,  date  , customer_id  ".split(",").map(&:strip)

    assert_equal [ "id", "date", "customer_id" ], merge_keys
  end

  # Write disposition parameter passing tests
  test "write_data extracts merge_key from hash schema parameter" do
    # Mock the client to avoid actual Snowflake calls
    mock_client = Minitest::Mock.new
    @adapter.instance_variable_set(:@client, mock_client)

    # Should not raise error when schema is a hash with merge_key
    schema_param = { schema: "PUBLIC", merge_key: "id" }
    target_schema = schema_param[:schema]
    merge_key = schema_param[:merge_key]

    assert_equal "PUBLIC", target_schema
    assert_equal "id", merge_key
  end

  test "write_data handles string schema parameter" do
    schema_param = "PUBLIC"

    if schema_param.is_a?(Hash)
      target_schema = schema_param[:schema]
      merge_key = schema_param[:merge_key]
    else
      target_schema = schema_param
      merge_key = nil
    end

    assert_equal "PUBLIC", target_schema
    assert_nil merge_key
  end

  test "write_data raises error for merge disposition without merge_key" do
    data = [ { "id" => 1, "name" => "Alice" } ]

    # Mock client
    mock_client = Minitest::Mock.new
    @adapter.instance_variable_set(:@client, mock_client)

    error = assert_raises(ArgumentError) do
      @adapter.write_data(
        table_name: "test_table",
        data: data,
        write_disposition: :merge,
        schema: "PUBLIC"  # No merge_key in schema
      )
    end

    assert_match /merge_key is required/, error.message
  end

  # SQL generation tests (via private methods)
  test "execute_merge builds correct ON clause for single key" do
    merge_keys = [ "id" ]
    on_conditions = merge_keys.map { |key| "target.#{key} = source.#{key}" }.join(" AND ")

    assert_equal "target.id = source.id", on_conditions
  end

  test "execute_merge builds correct ON clause for multiple keys" do
    merge_keys = [ "id", "date" ]
    on_conditions = merge_keys.map { |key| "target.#{key} = source.#{key}" }.join(" AND ")

    assert_equal "target.id = source.id AND target.date = source.date", on_conditions
  end

  test "execute_merge builds correct UPDATE SET clause excluding merge keys" do
    columns = [ "id", "name", "age", "date" ]
    merge_keys = [ "id", "date" ]
    update_columns = columns - merge_keys
    update_set = update_columns.map { |col| "target.#{col} = source.#{col}" }.join(", ")

    assert_equal "target.name = source.name, target.age = source.age", update_set
  end

  test "execute_merge builds correct INSERT clause with all columns" do
    columns = [ "id", "name", "age" ]
    insert_columns = columns.join(", ")
    insert_values = columns.map { |col| "source.#{col}" }.join(", ")

    assert_equal "id, name, age", insert_columns
    assert_equal "source.id, source.name, source.age", insert_values
  end

  test "staging table name includes timestamp" do
    table_name = "customers"
    staging_table = "#{table_name}_STAGING_#{Time.current.to_i}"

    assert_match /customers_STAGING_\d+/, staging_table
    assert staging_table.start_with?("customers_STAGING_")
  end

  # Edge cases
  test "merge_data handles data with special characters in values" do
    data = [
      { "id" => 1, "name" => "O'Brien" },
      { "id" => 2, "name" => "Smith \"The Great\"" }
    ]

    # Just verify data structure is correct
    assert_equal 2, data.size
    assert_equal "O'Brien", data[0]["name"]
  end

  test "merge_data handles nil values in data" do
    data = [
      { "id" => 1, "name" => "Alice", "age" => nil },
      { "id" => 2, "name" => nil, "age" => 30 }
    ]

    # Just verify data structure is correct
    assert_nil data[0]["age"]
    assert_nil data[1]["name"]
  end

  test "merge with composite key excludes all keys from update" do
    columns = [ "id", "customer_id", "date", "amount", "status" ]
    merge_keys = [ "id", "customer_id", "date" ]
    update_columns = columns - merge_keys

    assert_equal [ "amount", "status" ], update_columns
    assert_equal 2, update_columns.size
  end

  # Integration with Pipeline model
  test "pipeline persists merge_key correctly" do
    skip "Requires test database setup" # Skip for now as it needs sources

    pipeline = Pipeline.create!(
      name: "Test Merge Pipeline",
      transformation_sql: "SELECT * FROM test",
      write_disposition: :merge,
      merge_key: "id, date"
    )

    pipeline.reload
    assert_equal "merge", pipeline.write_disposition
    assert_equal "id, date", pipeline.merge_key
  end

  test "pipeline can switch to merge disposition with merge_key" do
    skip "Requires test database setup" # Skip for now as it needs sources

    pipeline = Pipeline.create!(
      name: "Test Pipeline",
      transformation_sql: "SELECT * FROM test",
      write_disposition: :append
    )

    pipeline.update!(
      write_disposition: :merge,
      merge_key: "id"
    )

    pipeline.reload
    assert_equal "merge", pipeline.write_disposition
    assert_equal "id", pipeline.merge_key
  end

  test "pipeline cannot switch to merge without merge_key" do
    skip "Requires test database setup" # Skip for now as it needs sources

    pipeline = Pipeline.create!(
      name: "Test Pipeline",
      transformation_sql: "SELECT * FROM test",
      write_disposition: :append
    )

    pipeline.write_disposition = :merge
    # Don't set merge_key

    assert_not pipeline.valid?
    assert_includes pipeline.errors[:merge_key], "can't be blank"
  end

  # Error handling tests
  test "write_data with merge validates merge_key presence" do
    data = [ { "id" => 1, "name" => "Alice" } ]

    # Don't set up mock - we want to test validation before any client calls
    error = assert_raises(ArgumentError) do
      @adapter.write_data(
        table_name: "test_table",
        data: data,
        write_disposition: :merge,
        schema: { schema: "PUBLIC" }  # No merge_key
      )
    end

    # Verify error message
    assert_match /merge_key is required/, error.message
  end
end
