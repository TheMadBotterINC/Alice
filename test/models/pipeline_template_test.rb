require "test_helper"

class PipelineTemplateTest < ActiveSupport::TestCase
  setup do
    @connector = connectors(:one)
    @pipeline = Pipeline.create!(
      name: "Test Pipeline",
      transformation_sql: "SELECT * FROM source",
      schedule: "0 2 * * *"
    )
    @pipeline.pipeline_sources.create!(connector: @connector)
  end

  # Template scope tests
  test "templates scope returns only templates" do
    template = Pipeline.create!(
      name: "Test Template",
      transformation_sql: "SELECT 1",
      is_template: true
    )
    template.pipeline_sources.create!(connector: @connector)

    templates = Pipeline.templates
    assert_includes templates, template
    refute_includes templates, @pipeline
  end

  test "pipelines scope returns only non-templates" do
    template = Pipeline.create!(
      name: "Test Template",
      transformation_sql: "SELECT 1",
      is_template: true
    )
    template.pipeline_sources.create!(connector: @connector)

    pipelines = Pipeline.pipelines
    assert_includes pipelines, @pipeline
    refute_includes pipelines, template
  end

  # save_as_template! tests
  test "save_as_template! creates a new template" do
    assert_difference "Pipeline.templates.count", 1 do
      template = @pipeline.save_as_template!("My Template")

      assert template.is_template?
      assert_equal "My Template", template.name
      assert_equal @pipeline.transformation_sql, template.transformation_sql
      assert_nil template.schedule # Templates don't have schedules
    end
  end

  test "save_as_template! copies pipeline sources" do
    template = @pipeline.save_as_template!("Template with Sources")

    assert_equal @pipeline.pipeline_sources.count, template.pipeline_sources.count
    assert_equal @pipeline.source_connectors.ids, template.source_connectors.ids
  end

  test "save_as_template! copies destination connector" do
    # Use a different connector (connectors(:two)) to avoid "same as source" validation error
    # since connectors(:one) is already used as a source in setup
    dest_connector = connectors(:two)
    @pipeline.update!(destination_connector: dest_connector)
    template = @pipeline.save_as_template!("Template with Destination")

    assert_equal @pipeline.destination_connector_id, template.destination_connector_id
  end

  test "save_as_template! copies write disposition" do
    @pipeline.update!(write_disposition: :truncate_and_load)
    template = @pipeline.save_as_template!("Template with Disposition")

    assert_equal "truncate_and_load", template.write_disposition
  end

  test "save_as_template! adds template origin to description" do
    @pipeline.update!(description: "Original description")
    template = @pipeline.save_as_template!("New Template")

    assert_includes template.description, "[Template created from: Test Pipeline]"
    assert_includes template.description, "Original description"
  end

  test "save_as_template! copies export format and options" do
    @pipeline.update!(
      export_format: "csv",
      export_options: { "delimiter" => ",", "has_header" => true }
    )
    template = @pipeline.save_as_template!("Export Template")

    assert_equal "csv", template.export_format
    assert_equal({ "delimiter" => ",", "has_header" => true }, template.export_options)
  end

  # create_from_template tests
  test "create_from_template creates a new pipeline from template" do
    template = Pipeline.create!(
      name: "Template",
      transformation_sql: "SELECT * FROM data",
      is_template: true
    )
    template.pipeline_sources.create!(connector: @connector)

    assert_difference "Pipeline.pipelines.count", 1 do
      pipeline = template.create_from_template(new_name: "New Pipeline")

      refute pipeline.is_template?
      assert_equal "New Pipeline", pipeline.name
      assert_equal template.transformation_sql, pipeline.transformation_sql
    end
  end

  test "create_from_template raises error if not a template" do
    assert_raises(ArgumentError) do
      @pipeline.create_from_template(new_name: "Should Fail")
    end
  end

  test "create_from_template copies sources" do
    template = Pipeline.create!(
      name: "Multi-Source Template",
      transformation_sql: "SELECT * FROM a JOIN b",
      is_template: true
    )
    template.pipeline_sources.create!(connector: @connector)
    template.pipeline_sources.create!(connector: connectors(:two))

    pipeline = template.create_from_template(new_name: "From Template")

    assert_equal 2, pipeline.pipeline_sources.count
    assert_equal template.source_connectors.ids.sort, pipeline.source_connectors.ids.sort
  end

  test "create_from_template accepts schedule parameter" do
    template = Pipeline.create!(
      name: "Scheduled Template",
      transformation_sql: "SELECT 1",
      is_template: true
    )
    template.pipeline_sources.create!(connector: @connector)

    pipeline = template.create_from_template(
      new_name: "Scheduled Pipeline",
      schedule: "0 3 * * *"
    )

    assert_equal "0 3 * * *", pipeline.schedule
  end

  test "create_from_template strips template metadata from description" do
    template = Pipeline.create!(
      name: "Template",
      description: "Description here\n\n[Template created from: Original]",
      transformation_sql: "SELECT 1",
      is_template: true
    )
    template.pipeline_sources.create!(connector: @connector)

    pipeline = template.create_from_template(new_name: "New")

    assert_equal "Description here", pipeline.description
    refute_includes pipeline.description, "[Template created from"
  end

  test "create_from_template copies destination" do
    template = Pipeline.create!(
      name: "Template",
      transformation_sql: "SELECT 1",
      destination_connector: @connector,
      write_disposition: :truncate_and_load,
      is_template: true
    )
    template.pipeline_sources.create!(connector: connectors(:two))

    pipeline = template.create_from_template(new_name: "With Destination")

    assert_equal @connector.id, pipeline.destination_connector_id
    assert_equal "truncate_and_load", pipeline.write_disposition
  end

  test "template and non-template can have same transformation SQL" do
    template = Pipeline.create!(
      name: "SQL Template",
      transformation_sql: "SELECT * FROM users",
      is_template: true
    )
    template.pipeline_sources.create!(connector: @connector)

    pipeline = Pipeline.create!(
      name: "SQL Pipeline",
      transformation_sql: "SELECT * FROM users",
      is_template: false
    )
    pipeline.pipeline_sources.create!(connector: @connector)

    assert template.valid?
    assert pipeline.valid?
  end

  test "templates can exist without schedule" do
    template = Pipeline.create!(
      name: "No Schedule Template",
      transformation_sql: "SELECT 1",
      schedule: nil,
      is_template: true
    )
    template.pipeline_sources.create!(connector: @connector)

    assert template.valid?
    assert_nil template.schedule
  end

  test "creating from template preserves source row limit" do
    template = Pipeline.create!(
      name: "Limited Template",
      transformation_sql: "SELECT * FROM big_table",
      source_row_limit: 50000,
      is_template: true
    )
    template.pipeline_sources.create!(connector: @connector)

    pipeline = template.create_from_template(new_name: "Limited Pipeline")

    assert_equal 50000, pipeline.source_row_limit
  end
end
