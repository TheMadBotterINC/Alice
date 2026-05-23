require "test_helper"

class PipelineFeatureVerificationTest < ActiveSupport::TestCase
  setup do
    @connector_source = connectors(:one) # Snowflake
    @connector_dest = connectors(:two)   # Another connector (likely Snowflake or Postgres, assuming it supports write or I'll pick one that does)
    
    # Ensure connectors(:two) supports write for the template test
    # If not, I'll use connectors(:one) as dest and something else as source
    # Let's check connectors(:two) type if possible, or just mock it/use a known one.
    # I'll use connectors(:powerbi_test) or :looking_glass_test as destination to be safe.
    @connector_looking_glass = connectors(:looking_glass_test)
    @connector_duckdb = connectors(:duckdb_local)
    
    @pipeline = Pipeline.new(
      name: "Feature Verification Pipeline",
      description: "Test description",
      transformation_sql: "SELECT * FROM source_table"
    )
  end

  # Case 1: Looking Glass connector type is recognized as valid during validation
  test "Looking Glass connector type is recognized as valid during validation" do
    @pipeline.pipeline_sources.build(connector: @connector_source)
    @pipeline.destination_connector = @connector_looking_glass
    @pipeline.destination_config = { api_key: "test_key", api_url: "https://api.example.com", connection_id: "123" }
    
    assert @pipeline.valid?, "Pipeline should be valid with Looking Glass destination"
    assert_empty @pipeline.errors[:destination_connector_id]
  end

  # Case 2: Pipeline.save_as_template! correctly copies destination connector with different connectors
  test "save_as_template! correctly copies destination connector with different connectors" do
    # Setup pipeline with source != destination
    @pipeline.pipeline_sources.build(connector: @connector_source)
    @pipeline.destination_connector = @connector_looking_glass
    @pipeline.destination_config = { api_key: "test_key", api_url: "https://api.example.com", connection_id: "123" }
    @pipeline.save!

    template_name = "Template from Feature Verification"
    template = @pipeline.save_as_template!(template_name)

    assert template.is_template?
    assert_equal template_name, template.name
    
    # Verify destination connector is copied
    assert_equal @pipeline.destination_connector_id, template.destination_connector_id
    assert_equal @connector_looking_glass.id, template.destination_connector_id
    
    # Verify source connector is copied
    assert_equal 1, template.pipeline_sources.count
    assert_equal @connector_source.id, template.pipeline_sources.first.connector_id
    
    # Verify they are different
    assert_not_equal template.pipeline_sources.first.connector_id, template.destination_connector_id
  end

  # Case 3: Pipeline allows Snowflake connectors as destination under correct conditions
  test "Pipeline allows Snowflake connectors as destination under correct conditions" do
    # Correct conditions: Connector exists, supports write, and is not a source
    snowflake_dest = connectors(:two) # Assuming 'two' is snowflake or I can use 'one' if source is different
    
    # Let's check if 'two' is snowflake. If not, I'll reuse 'one' as dest and use 'duckdb' as source (if allowed as source)
    # Actually, let's use @connector_source (Snowflake) as destination, and a Dataset as source to avoid conflict
    
    @pipeline.pipeline_sources.clear
    @pipeline.pipeline_sources.build(dataset: datasets(:sales_summary))
    @pipeline.destination_connector = @connector_source # Snowflake
    
    # Snowflake doesn't require destination_config in validation currently (based on Pipeline model)
    # But let's check validation_destination_config method.
    # It checks config based on type. For Snowflake, it's not checking anything specific in 'validate_destination_config' 
    # except 'if destination_connector_id.blank?' and checking valid connector.
    
    assert @pipeline.valid?, "Pipeline should be valid with Snowflake destination"
    assert_empty @pipeline.errors[:destination_connector_id]
  end

  # Case 4: Pipeline rejects DuckDB connectors as destination with appropriate error message
  test "Pipeline rejects DuckDB connectors as destination with appropriate error message" do
    @pipeline.pipeline_sources.build(connector: @connector_source)
    @pipeline.destination_connector = @connector_duckdb
    
    assert_not @pipeline.valid?
    assert_includes @pipeline.errors[:destination_connector_id], 
      "must be a valid destination connector (Snowflake, PostgreSQL, PowerBI, Looking Glass). 'DuckDB Local' is a duckdb connector."
  end
end
