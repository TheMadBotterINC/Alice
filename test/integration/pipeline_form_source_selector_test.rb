require "test_helper"

class PipelineFormSourceSelectorTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @connector = connectors(:one)
    @dataset = datasets(:sales_summary)
  end

  test "new pipeline form shows connector source type by default" do
    post sign_in_url, params: { email: @admin.email, password: "password123" }

    get new_pipeline_url
    assert_response :success

    # Should show source type radio buttons
    assert_select "input[type='radio'][name='source_type'][value='connectors']"
    assert_select "input[type='radio'][name='source_type'][value='datasets']"

    # Should show Data Sources section
    assert_select "h3", text: "Data Sources"
  end

  test "edit form pre-selects connector source type when pipeline has connector sources" do
    post sign_in_url, params: { email: @admin.email, password: "password123" }

    # Create pipeline with connector source
    pipeline = Pipeline.create!(
      name: "Connector Pipeline",
      transformation_sql: "SELECT 1"
    )
    pipeline.pipeline_sources.create!(connector: @connector)

    get edit_pipeline_url(pipeline)
    assert_response :success

    # Connector radio should be checked
    assert_select "input[type='radio'][name='source_type'][value='connectors'][checked]"
  end

  test "edit form pre-selects dataset source type when pipeline has dataset sources" do
    post sign_in_url, params: { email: @admin.email, password: "password123" }

    # Create pipeline with dataset source
    pipeline = Pipeline.create!(
      name: "Dataset Pipeline",
      transformation_sql: "SELECT 1"
    )
    pipeline.pipeline_sources.create!(dataset: @dataset)

    get edit_pipeline_url(pipeline)
    assert_response :success

    # Dataset radio should be checked
    assert_select "input[type='radio'][name='source_type'][value='datasets'][checked]"
  end

  test "form shows connector checkboxes section" do
    post sign_in_url, params: { email: @admin.email, password: "password123" }

    get new_pipeline_url
    assert_response :success

    # Should have connector checkboxes with proper IDs
    assert_select "input[type='checkbox'][name='pipeline[source_connector_ids][]']"
  end

  test "form shows dataset checkboxes section" do
    post sign_in_url, params: { email: @admin.email, password: "password123" }

    get new_pipeline_url
    assert_response :success

    # Should have dataset checkboxes with proper IDs
    assert_select "input[type='checkbox'][name='pipeline[source_dataset_ids][]']"
  end

  test "form includes Stimulus controller attributes" do
    post sign_in_url, params: { email: @admin.email, password: "password123" }

    get new_pipeline_url
    assert_response :success

    # Should have source-selector controller
    assert_select "[data-controller='source-selector']"

    # Radio buttons should have Stimulus targets and actions
    assert_select "input[data-source-selector-target='typeRadio']"
    assert_select "input[data-action*='source-selector#switchType']"
  end

  test "new pipeline with preselected dataset shows dataset as source type" do
    post sign_in_url, params: { email: @admin.email, password: "password123" }

    get new_pipeline_url(source_dataset_id: @dataset.id)
    assert_response :success

    # Should show preselection notification
    assert_select ".bg-blue-50", text: /Dataset Pre-selected as Source/
    assert_select ".bg-blue-50", text: /#{@dataset.name}/

    # Dataset radio should be checked
    assert_select "input[type='radio'][name='source_type'][value='datasets'][checked]"
  end

  test "form provides helpful context for source types" do
    post sign_in_url, params: { email: @admin.email, password: "password123" }

    get new_pipeline_url
    assert_response :success

    # Should explain the difference between source types
    assert_select "label", text: /Connectors.*Database\/API sources/
    assert_select "label", text: /Datasets.*Pipeline chaining/
  end
end
