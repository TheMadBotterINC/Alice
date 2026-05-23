require "test_helper"

class PipelinesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @pipeline = pipelines(:one)
    @connector = connectors(:one)
    @admin = users(:admin_user)
    @admin = users(:admin_user)
    @viewer = users(:viewer_user)
  end

  # Index Tests
  test "should require login to access index" do
    get pipelines_url
    assert_redirected_to sign_in_url
  end

  test "should get index when logged in" do
    sign_in_as(@viewer)
    get pipelines_url
    assert_response :success
  end

  test "should display pipelines in index" do
    sign_in_as(@viewer)
    get pipelines_url
    assert_select "h1", text: "Pipelines"
  end

  # Show Tests
  test "should require login to show pipeline" do
    get pipeline_url(@pipeline)
    assert_redirected_to sign_in_url
  end

  test "should show pipeline when logged in" do
    sign_in_as(@viewer)
    get pipeline_url(@pipeline)
    assert_response :success
  end

  test "should display pipeline details" do
    sign_in_as(@viewer)
    get pipeline_url(@pipeline)
    assert_select "h1", text: @pipeline.name
  end

  # New Tests
  test "should require login to access new" do
    get new_pipeline_url
    assert_redirected_to sign_in_url
  end

  test "should allow admin to access new" do
    sign_in_as(@admin)
    get new_pipeline_url
    assert_response :success
  end

  test "should not allow viewer to access new" do
    sign_in_as(@viewer)
    get new_pipeline_url
    assert_redirected_to root_path
  end

  # Create Tests
  test "should allow admin to create pipeline" do
    sign_in_as(@admin)
    assert_difference("Pipeline.count") do
      post pipelines_url, params: {
        pipeline: {
          name: "New Test Pipeline",
          description: "A test pipeline",
          source_connector_ids: [ @connector.id ],
          transformation_sql: "SELECT * FROM test_table",
          schedule: "0 2 * * *"
        }
      }
    end
    assert_redirected_to pipeline_url(Pipeline.last)
  end

  test "should not allow viewer to create pipeline" do
    sign_in_as(@viewer)
    assert_no_difference("Pipeline.count") do
      post pipelines_url, params: {
        pipeline: {
          name: "Viewer Pipeline",
          source_connector_ids: [ @connector.id ],
          transformation_sql: "SELECT * FROM data"
        }
      }
    end
    assert_redirected_to root_path
  end

  test "should not create pipeline with invalid data" do
    sign_in_as(@admin)
    assert_no_difference("Pipeline.count") do
      post pipelines_url, params: {
        pipeline: {
          name: "",
          source_connector_ids: [],
          transformation_sql: ""
        }
      }
    end
    assert_response :unprocessable_entity
  end

  # Edit Tests
  test "should allow admin to access edit" do
    sign_in_as(@admin)
    get edit_pipeline_url(@pipeline)
    assert_response :success
  end

  test "should not allow viewer to access edit" do
    sign_in_as(@viewer)
    get edit_pipeline_url(@pipeline)
    assert_redirected_to root_path
  end

  # Update Tests
  test "should allow admin to update pipeline" do
    sign_in_as(@admin)
    patch pipeline_url(@pipeline), params: {
      pipeline: {
        name: "Updated Pipeline Name"
      }
    }
    assert_redirected_to pipeline_url(@pipeline)
    @pipeline.reload
    assert_equal "Updated Pipeline Name", @pipeline.name
  end

  test "should not allow viewer to update pipeline" do
    sign_in_as(@viewer)
    original_name = @pipeline.name
    patch pipeline_url(@pipeline), params: {
      pipeline: {
        name: "Updated by Viewer"
      }
    }
    assert_redirected_to root_path
    @pipeline.reload
    assert_equal original_name, @pipeline.name
  end

  test "should not update pipeline with invalid data" do
    sign_in_as(@admin)
    original_name = @pipeline.name
    patch pipeline_url(@pipeline), params: {
      pipeline: {
        name: ""
      }
    }
    assert_response :unprocessable_entity
    @pipeline.reload
    assert_equal original_name, @pipeline.name
  end

  # Destroy Tests
  test "should allow admin to destroy pipeline" do
    sign_in_as(@admin)
    assert_difference("Pipeline.count", -1) do
      delete pipeline_url(@pipeline)
    end
    assert_redirected_to pipelines_path
  end

  test "should not allow viewer to destroy pipeline" do
    sign_in_as(@viewer)
    assert_no_difference("Pipeline.count") do
      delete pipeline_url(@pipeline)
    end
    assert_redirected_to root_path
  end

  # Run Tests
  test "should allow admin to run pipeline" do
    sign_in_as(@admin)
    assert_difference("PipelineRun.count") do
      post run_pipeline_url(@pipeline)
    end
    assert_redirected_to pipeline_url(@pipeline)
    assert_equal "Pipeline run has been queued and will execute shortly.", flash[:notice]
  end

  test "should not allow viewer to run pipeline" do
    sign_in_as(@viewer)
    assert_no_difference("PipelineRun.count") do
      post run_pipeline_url(@pipeline)
    end
    assert_redirected_to root_path
  end

  test "pipeline run should be created with pending status" do
    sign_in_as(@admin)
    post run_pipeline_url(@pipeline)
    run = PipelineRun.last
    assert_equal "pending", run.status
    assert_equal @pipeline.id, run.pipeline_id
    assert_not_nil run.started_at
  end

  # Multi-Source Tests
  test "should create pipeline with multiple source connectors" do
    sign_in_as(@admin)
    connector2 = connectors(:two)
    connector3 = connectors(:three)

    assert_difference("Pipeline.count", 1) do
      assert_difference("PipelineSource.count", 2) do
        post pipelines_url, params: {
          pipeline: {
            name: "Multi-Source Pipeline",
            transformation_sql: "SELECT * FROM source1 UNION ALL SELECT * FROM source2",
            source_connector_ids: [ connector2.id, connector3.id, "" ],
            connector_tables: {
              connector2.id.to_s => { schema: "PUBLIC", table: "TABLE1" },
              connector3.id.to_s => { schema: "PUBLIC", table: "TABLE2" }
            }
          }
        }
      end
    end

    pipeline = Pipeline.last
    # Should have created datasets and associated them as sources
    assert_equal 2, pipeline.source_datasets.count
    # Check that datasets were auto-created
    assert Dataset.exists?(connector: connector2, schema_name: "PUBLIC", table_name: "TABLE1")
    assert Dataset.exists?(connector: connector3, schema_name: "PUBLIC", table_name: "TABLE2")
  end

  test "should update pipeline source connectors" do
    sign_in_as(@admin)
    connector2 = connectors(:two)
    connector3 = connectors(:three)

    # Pipeline initially has one source (from fixtures)
    initial_source_count = @pipeline.source_connectors.count

    patch pipeline_url(@pipeline), params: {
      pipeline: {
        source_connector_ids: [ connector2.id, connector3.id ],
        connector_tables: {
          connector2.id.to_s => { schema: "PUBLIC", table: "TABLE_A" },
          connector3.id.to_s => { schema: "PUBLIC", table: "TABLE_B" }
        }
      }
    }

    @pipeline.reload
    # Should have created datasets and associated them as sources
    assert_equal 2, @pipeline.source_datasets.count
  end

  test "should set destination connector" do
    sign_in_as(@admin)
    dest_connector = connectors(:two) # Snowflake connector

    post pipelines_url, params: {
      pipeline: {
        name: "Pipeline with Destination",
        transformation_sql: "SELECT 1",
        source_connector_ids: [ @connector.id ],
        destination_connector_id: dest_connector.id,
        write_disposition: "truncate_and_load"
      }
    }

    pipeline = Pipeline.last
    assert_equal dest_connector, pipeline.destination_connector
    assert_equal "truncate_and_load", pipeline.write_disposition
  end

  test "should handle empty source_connector_ids array" do
    sign_in_as(@admin)

    # In test environment, the validation is skipped to allow fixture-style creation
    # In production, this would fail validation
    post pipelines_url, params: {
      pipeline: {
        name: "Test Pipeline No Sources",
        transformation_sql: "SELECT 1",
        source_connector_ids: [ "" ]
      }
    }

    # Pipeline is created even without sources (test env only)
    assert_redirected_to pipeline_url(Pipeline.last)
  end

  test "should update write_disposition" do
    sign_in_as(@admin)

    patch pipeline_url(@pipeline), params: {
      pipeline: {
        write_disposition: "merge",
        merge_key: "id"
      }
    }

    @pipeline.reload
    assert_equal "merge", @pipeline.write_disposition
    assert_equal "id", @pipeline.merge_key
  end

  test "should allow nullable destination_connector" do
    sign_in_as(@admin)

    post pipelines_url, params: {
      pipeline: {
        name: "No Destination Pipeline",
        transformation_sql: "SELECT 1",
        source_connector_ids: [ @connector.id ],
        destination_connector_id: ""
      }
    }

    pipeline = Pipeline.last
    assert_nil pipeline.destination_connector
  end

  # Dataset Source Tests
  test "should pre-select dataset when source_dataset_id parameter is present" do
    sign_in_as(@admin)
    dataset = datasets(:sales_summary)

    get new_pipeline_url(source_dataset_id: dataset.id)

    assert_response :success
    # Verify that the preselection notification banner is shown
    assert_select ".bg-blue-50", text: /Dataset Pre-selected as Source/
    assert_select ".bg-blue-50", text: /#{dataset.name}/
  end

  test "should handle invalid source_dataset_id gracefully" do
    sign_in_as(@admin)

    get new_pipeline_url(source_dataset_id: 999999)

    assert_response :success
    # Should still load the form successfully without pre-selection
  end

  test "should create pipeline with dataset sources" do
    sign_in_as(@admin)
    dataset1 = datasets(:sales_summary)
    dataset2 = datasets(:user_analytics)

    assert_difference("Pipeline.count", 1) do
      assert_difference("PipelineSource.count", 2) do
        post pipelines_url, params: {
          pipeline: {
            name: "Dataset Source Pipeline",
            transformation_sql: "SELECT * FROM dataset_table",
            source_dataset_ids: [ dataset1.id, dataset2.id, "" ]
          }
        }
      end
    end

    pipeline = Pipeline.last
    assert_equal 2, pipeline.source_datasets.count
    assert_includes pipeline.source_datasets, dataset1
    assert_includes pipeline.source_datasets, dataset2
  end

  test "should update pipeline dataset sources" do
    sign_in_as(@admin)
    dataset1 = datasets(:sales_summary)
    dataset2 = datasets(:user_analytics)

    patch pipeline_url(@pipeline), params: {
      pipeline: {
        source_dataset_ids: [ dataset1.id, dataset2.id ]
      }
    }

    @pipeline.reload
    assert_equal 2, @pipeline.source_datasets.count
    assert_includes @pipeline.source_datasets, dataset1
    assert_includes @pipeline.source_datasets, dataset2
  end

  test "should switch from connector to dataset sources" do
    sign_in_as(@admin)
    dataset = datasets(:sales_summary)

    # Pipeline initially has connector source
    assert @pipeline.source_connectors.any?
    assert @pipeline.source_datasets.empty?

    # Update to use dataset sources instead
    patch pipeline_url(@pipeline), params: {
      pipeline: {
        source_connector_ids: [ "" ],
        source_dataset_ids: [ dataset.id ]
      }
    }

    @pipeline.reload
    assert_equal 0, @pipeline.source_connectors.count
    assert_equal 1, @pipeline.source_datasets.count
    assert_includes @pipeline.source_datasets, dataset
  end

  private

  def sign_in_as(user)
    post sign_in_url, params: { email: user.email, password: "password123" }
  end
end
