require "test_helper"

class PipelineSourceTest < ActiveSupport::TestCase
  def setup
    @pipeline = Pipeline.new(
      name: "Test Pipeline",
      transformation_sql: "SELECT * FROM source_table"
    )
    @connector = connectors(:one)
  end

  test "should be valid with valid connector" do
    pipeline_source = @pipeline.pipeline_sources.build(connector: @connector)
    assert pipeline_source.valid?
  end

  test "should be valid with valid dataset" do
    dataset = datasets(:sales_summary)
    pipeline_source = @pipeline.pipeline_sources.build(dataset: dataset)
    assert pipeline_source.valid?
  end

  test "should require either connector or dataset" do
    pipeline_source = @pipeline.pipeline_sources.build
    assert_not pipeline_source.valid?
    assert_includes pipeline_source.errors[:base], "Must have either a connector or a dataset"
  end

  test "should not allow both connector and dataset" do
    dataset = datasets(:sales_summary)
    pipeline_source = @pipeline.pipeline_sources.build(
      connector: @connector,
      dataset: dataset
    )
    assert_not pipeline_source.valid?
    assert_includes pipeline_source.errors[:base], "Cannot have both a connector and a dataset"
  end

  test "should auto-generate table_alias from connector name" do
    pipeline_source = @pipeline.pipeline_sources.build(connector: @connector)
    pipeline_source.valid? # trigger callbacks
    assert_not_nil pipeline_source.table_alias
    assert_match /^[a-z0-9_]+$/, pipeline_source.table_alias
  end

  test "should auto-generate table_alias from dataset name" do
    dataset = datasets(:sales_summary)
    pipeline_source = @pipeline.pipeline_sources.build(dataset: dataset)
    pipeline_source.valid? # trigger callbacks
    assert_not_nil pipeline_source.table_alias
    assert_match /^[a-z0-9_]+$/, pipeline_source.table_alias
  end

  test "should validate table_alias format" do
    pipeline_source = @pipeline.pipeline_sources.build(
      connector: @connector,
      table_alias: "invalid-alias"
    )
    assert_not pipeline_source.valid?
    assert_includes pipeline_source.errors[:table_alias], "must be a valid SQL table name"
  end

  test "should allow valid table_alias formats" do
    valid_aliases = ["table1", "_table", "table_name", "TABLE_NAME", "t1"]
    valid_aliases.each do |alias_name|
      pipeline_source = @pipeline.pipeline_sources.build(
        connector: @connector,
        table_alias: alias_name
      )
      assert pipeline_source.valid?, "Expected '#{alias_name}' to be valid"
    end
  end

  # Destination-only Connector Tests

  test "should not allow PowerBI connector as source" do
    powerbi = connectors(:powerbi_test)
    pipeline_source = @pipeline.pipeline_sources.build(connector: powerbi)
    assert_not pipeline_source.valid?
    assert_includes pipeline_source.errors[:connector_id],
      "'Test Power BI' is a powerbi connector and can only be used as a destination, not a source"
  end

  test "should not allow Looking Glass connector as source" do
    looking_glass = connectors(:looking_glass_test)
    pipeline_source = @pipeline.pipeline_sources.build(connector: looking_glass)
    assert_not pipeline_source.valid?
    assert_includes pipeline_source.errors[:connector_id],
      "'Test Looking Glass' is a looking_glass connector and can only be used as a destination, not a source"
  end

  test "should allow Snowflake connector as source" do
    snowflake = connectors(:one)
    pipeline_source = @pipeline.pipeline_sources.build(connector: snowflake)
    assert pipeline_source.valid?
  end

  test "should allow DuckDB connector as source" do
    duckdb = connectors(:duckdb_local)
    pipeline_source = @pipeline.pipeline_sources.build(connector: duckdb)
    assert pipeline_source.valid?
  end

  test "source method returns connector when connector is set" do
    pipeline_source = @pipeline.pipeline_sources.build(connector: @connector)
    assert_equal @connector, pipeline_source.source
  end

  test "source method returns dataset when dataset is set" do
    dataset = datasets(:sales_summary)
    pipeline_source = @pipeline.pipeline_sources.build(dataset: dataset)
    assert_equal dataset, pipeline_source.source
  end

  test "source_type returns 'connector' when connector is set" do
    pipeline_source = @pipeline.pipeline_sources.build(connector: @connector)
    assert_equal "connector", pipeline_source.source_type
  end

  test "source_type returns 'dataset' when dataset is set" do
    dataset = datasets(:sales_summary)
    pipeline_source = @pipeline.pipeline_sources.build(dataset: dataset)
    assert_equal "dataset", pipeline_source.source_type
  end

  test "source_name returns connector name" do
    pipeline_source = @pipeline.pipeline_sources.build(connector: @connector)
    assert_equal @connector.name, pipeline_source.source_name
  end

  test "source_name returns dataset name" do
    dataset = datasets(:sales_summary)
    pipeline_source = @pipeline.pipeline_sources.build(dataset: dataset)
    assert_equal dataset.name, pipeline_source.source_name
  end
end
