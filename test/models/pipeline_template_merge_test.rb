require "test_helper"

class PipelineTemplateMergeTest < ActiveSupport::TestCase
  setup do
    @connector = connectors(:one)
  end

  test "save_as_template preserves merge_key" do
    # Create a pipeline with merge disposition and merge_key
    pipeline = Pipeline.new(
      name: "Original Pipeline",
      transformation_sql: "SELECT * FROM test",
      write_disposition: :merge,
      merge_key: "id, customer_id"
    )

    # Add a source to satisfy validation
    pipeline.pipeline_sources.build(connector: @connector, table_alias: "test")
    pipeline.save!

    # Save as template
    template = pipeline.save_as_template!("Test Merge Template")

    # Verify template preserves merge settings
    assert template.is_template?
    assert_equal "merge", template.write_disposition
    assert_equal "id, customer_id", template.merge_key
    assert_equal pipeline.transformation_sql, template.transformation_sql
  end

  test "create_from_template preserves merge_key" do
    # Create a template with merge disposition
    template = Pipeline.new(
      name: "Merge Template",
      transformation_sql: "SELECT * FROM source",
      write_disposition: :merge,
      merge_key: "user_id",
      is_template: true
    )

    # Add a source
    template.pipeline_sources.build(connector: @connector, table_alias: "source")
    template.save!

    # Create pipeline from template
    pipeline = template.create_from_template(new_name: "New Pipeline from Template", schedule: "0 2 * * *")

    # Verify pipeline has merge settings from template
    assert_not pipeline.is_template?
    assert_equal "merge", pipeline.write_disposition
    assert_equal "user_id", pipeline.merge_key
    assert_equal "0 2 * * *", pipeline.schedule
    assert_equal template.transformation_sql, pipeline.transformation_sql
  end

  test "save_as_template with append disposition has nil merge_key" do
    # Create a pipeline with append (no merge_key needed)
    pipeline = Pipeline.new(
      name: "Append Pipeline",
      transformation_sql: "SELECT * FROM test",
      write_disposition: :append
    )

    pipeline.pipeline_sources.build(connector: @connector, table_alias: "test")
    pipeline.save!

    # Save as template
    template = pipeline.save_as_template!("Append Template")

    # Verify template has append with no merge_key
    assert_equal "append", template.write_disposition
    assert_nil template.merge_key
  end

  test "template with merge requires merge_key on creation from template" do
    # Create a template with merge but somehow no merge_key (edge case)
    template = Pipeline.new(
      name: "Broken Template",
      transformation_sql: "SELECT * FROM source",
      write_disposition: :merge,
      merge_key: nil,  # Invalid for merge!
      is_template: true
    )

    template.pipeline_sources.build(connector: @connector, table_alias: "source")

    # Should fail validation because merge requires merge_key
    assert_not template.valid?
    assert_includes template.errors[:merge_key], "can't be blank"
  end

  test "switching template from append to merge requires adding merge_key" do
    # Create an append template
    template = Pipeline.new(
      name: "Append Template",
      transformation_sql: "SELECT * FROM test",
      write_disposition: :append,
      is_template: true
    )

    template.pipeline_sources.build(connector: @connector, table_alias: "test")
    template.save!

    # Try to change to merge without adding merge_key
    template.write_disposition = :merge

    # Should fail validation
    assert_not template.valid?
    assert_includes template.errors[:merge_key], "can't be blank"

    # Now add merge_key and it should be valid
    template.merge_key = "id"
    assert template.valid?
  end

  test "template created from merge pipeline can be used multiple times" do
    # Create original pipeline with merge
    pipeline = Pipeline.new(
      name: "Original Merge Pipeline",
      transformation_sql: "SELECT * FROM data",
      write_disposition: :merge,
      merge_key: "transaction_id"
    )

    pipeline.pipeline_sources.build(connector: @connector, table_alias: "data")
    pipeline.save!

    # Save as template
    template = pipeline.save_as_template!("Reusable Merge Template")

    # Create multiple pipelines from same template
    pipeline1 = template.create_from_template(new_name: "Daily Merge Pipeline")
    pipeline2 = template.create_from_template(new_name: "Hourly Merge Pipeline")

    # Both should have merge_key
    assert_equal "transaction_id", pipeline1.merge_key
    assert_equal "transaction_id", pipeline2.merge_key
    assert_equal "merge", pipeline1.write_disposition
    assert_equal "merge", pipeline2.write_disposition
  end
end
