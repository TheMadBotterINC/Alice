require "test_helper"

class DatasetTest < ActiveSupport::TestCase
  setup do
    @dataset = datasets(:sales_summary)
    @connector = connectors(:one)
  end

  # Validation tests
  test "should be valid with valid attributes" do
    assert @dataset.valid?
  end

  test "should require name" do
    @dataset.name = nil
    assert_not @dataset.valid?
    assert_includes @dataset.errors[:name], "can't be blank"
  end

  test "should require unique name" do
    duplicate = Dataset.new(
      name: @dataset.name,
      table_name: "different_table",
      schema_name: "PUBLIC",
      connector: @connector
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "should require table_name" do
    @dataset.table_name = nil
    assert_not @dataset.valid?
    assert_includes @dataset.errors[:table_name], "can't be blank"
  end

  test "should validate table_name format" do
    invalid_names = [ "123invalid", "invalid-name", "invalid name", "invalid.name" ]
    invalid_names.each do |name|
      @dataset.table_name = name
      assert_not @dataset.valid?, "#{name} should be invalid"
      assert_includes @dataset.errors[:table_name], "must be a valid table name"
    end
  end

  test "should accept valid table_names" do
    valid_names = [ "valid_table", "ValidTable", "_underscore", "table123", "TABLE_NAME" ]
    valid_names.each do |name|
      @dataset.table_name = name
      @dataset.schema_name = "PUBLIC"  # Ensure schema_name is set
      assert @dataset.valid?, "#{name} should be valid but got errors: #{@dataset.errors.full_messages.join(', ')}"
    end
  end

  test "should require connector" do
    @dataset.connector = nil
    assert_not @dataset.valid?
    assert_includes @dataset.errors[:connector], "must exist"
  end

  test "should require schema_name" do
    @dataset.schema_name = nil
    assert_not @dataset.valid?
    assert_includes @dataset.errors[:schema_name], "can't be blank"
  end

  test "should enforce uniqueness of table_name scoped to connector and schema" do
    duplicate = Dataset.new(
      name: "Different Name",
      table_name: @dataset.table_name,
      schema_name: @dataset.schema_name,
      connector: @dataset.connector
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:table_name], "already exists for this connector and schema"
  end

  test "should allow same table_name with different connector" do
    different_connector = connectors(:two)
    duplicate = Dataset.new(
      name: "Different Name",
      table_name: @dataset.table_name,
      schema_name: @dataset.schema_name,
      connector: different_connector
    )
    assert duplicate.valid?
  end

  test "should allow same table_name with different schema" do
    duplicate = Dataset.new(
      name: "Different Name",
      table_name: @dataset.table_name,
      schema_name: "DIFFERENT_SCHEMA",
      connector: @dataset.connector
    )
    assert duplicate.valid?
  end

  # Association tests
  test "should belong to connector" do
    assert_equal @connector, @dataset.connector
  end

  # Note: Dataset doesn't have a direct pipelines relationship
  # Pipelines reference datasets through their source connectors

  # Enum tests
  test "should have status enum" do
    assert_equal "active", @dataset.status

    @dataset.draft!
    assert @dataset.draft?

    @dataset.active!
    assert @dataset.active?

    @dataset.archived!
    assert @dataset.archived?
  end

  test "should default to draft status" do
    new_dataset = Dataset.new(
      name: "New Dataset",
      table_name: "new_table",
      schema_name: "PUBLIC",
      connector: @connector
    )
    assert_equal "draft", new_dataset.status
  end

  # Scope tests
  test "recent scope should order by created_at desc" do
    all_datasets = Dataset.recent.to_a
    # Check that they're in descending created_at order
    all_datasets.each_cons(2) do |newer, older|
      assert newer.created_at >= older.created_at, "Datasets should be ordered by created_at descending"
    end
  end

  test "active scope should return only active datasets" do
    Dataset.update_all(status: :draft)
    @dataset.reload
    @dataset.update!(status: :active)

    active_datasets = Dataset.active.to_a
    assert_equal 1, active_datasets.count
    assert_equal @dataset.id, active_datasets.first.id
  end

  test "readable scope should exclude file-based datasets" do
    # Create a file-based connector
    file_connector = Connector.create!(
      name: "Test CSV Connector",
      connector_type: "file_csv",
      config: { "mode" => "upload" }
    )

    # Create a dataset with file connector
    file_dataset = Dataset.create!(
      name: "Test CSV Dataset",
      table_name: "test_csv",
      schema_name: "local",
      connector: file_connector
    )

    # Readable scope should exclude file datasets
    readable_datasets = Dataset.readable.to_a
    assert_not_includes readable_datasets, file_dataset
    assert_includes readable_datasets, @dataset
  end

  # Instance method tests
  test "column_names should return array of column names" do
    expected = [ "sale_date", "product_category", "total_orders", "total_revenue" ]
    assert_equal expected, @dataset.column_names
  end

  test "column_names should return empty array if no schema" do
    @dataset.schema = nil
    assert_equal [], @dataset.column_names
  end

  test "column_types should return hash of column types" do
    expected = {
      "sale_date" => "DATE",
      "product_category" => "VARCHAR",
      "total_orders" => "INTEGER",
      "total_revenue" => "DECIMAL"
    }
    assert_equal expected, @dataset.column_types
  end

  test "column_types should return empty hash if no schema" do
    @dataset.schema = nil
    assert_equal({}, @dataset.column_types)
  end

  test "status_variant should return correct variant" do
    @dataset.draft!
    assert_equal :warning, @dataset.status_variant

    @dataset.active!
    assert_equal :success, @dataset.status_variant

    @dataset.archived!
    assert_equal :gray, @dataset.status_variant
  end

  test "fully_qualified_name should combine connector and table name" do
    expected = "#{@connector.name}.#{@dataset.schema_name}.#{@dataset.table_name}"
    assert_equal expected, @dataset.fully_qualified_name
  end

  test "source_table_path should combine database, schema, and table name" do
    expected = "#{@connector.config['database']}.#{@dataset.schema_name}.#{@dataset.table_name}"
    assert_equal expected, @dataset.source_table_path
  end

  # Note: Datasets can be deleted independently
  # Pipelines reference connectors, not datasets directly
end
