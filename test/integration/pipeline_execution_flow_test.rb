require "test_helper"

class PipelineExecutionFlowTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @source1 = connectors(:one)
    @source2 = connectors(:two)
    @destination = connectors(:three)
  end

  test "complete pipeline creation and execution flow" do
    # Step 1: Sign in as admin
    post sign_in_url, params: { email: @admin.email, password: "password123" }
    assert_response :redirect
    follow_redirect!

    # Step 2: Navigate to new pipeline form
    get new_pipeline_url
    assert_response :success
    assert_select "h1", "New Pipeline"

    # Step 3: Create pipeline with multiple sources
    assert_difference("Pipeline.count", 1) do
      assert_difference("PipelineSource.count", 2) do
        post pipelines_url, params: {
          pipeline: {
            name: "Integration Test Pipeline",
            description: "Testing end-to-end pipeline execution",
            transformation_sql: "SELECT * FROM production_snowflake UNION ALL SELECT * FROM staging_snowflake",
            source_connector_ids: [ @source1.id, @source2.id, "" ],
            connector_tables: {
              @source1.id.to_s => { schema: "PUBLIC", table: "PROD_TABLE" },
              @source2.id.to_s => { schema: "PUBLIC", table: "STAGING_TABLE" }
            },
            destination_connector_id: @destination.id,
            write_disposition: "append",
            schedule: "0 2 * * *"
          }
        }
      end
    end

    assert_redirected_to pipeline_url(Pipeline.last)
    pipeline = Pipeline.last

    # Step 4: Verify pipeline was created correctly
    assert_equal "Integration Test Pipeline", pipeline.name
    assert_equal 2, pipeline.source_datasets.count
    assert_equal @destination, pipeline.destination_connector
    assert_equal "append", pipeline.write_disposition

    # Step 5: View the pipeline details
    get pipeline_url(pipeline)
    assert_response :success
    assert_select "h1", pipeline.name
    assert_select "dt", text: "Data Sources"

    # Step 6: Run the pipeline
    assert_difference("PipelineRun.count") do
      post run_pipeline_url(pipeline)
    end

    assert_redirected_to pipeline_url(pipeline)
    follow_redirect!
    # Flash messages use bg-success class for notices
    assert_select ".bg-success", text: /queued/i

    # Step 7: Verify pipeline run was created
    pipeline_run = pipeline.pipeline_runs.last
    assert_equal "pending", pipeline_run.status
    assert_not_nil pipeline_run.started_at

    # Step 8: Execute the pipeline run (simulate job execution)
    mock_service = Minitest::Mock.new
    mock_service.expect(:execute, {
      success: true,
      sources_loaded: 2,
      transformation_rows: 250,
      execution_time_ms: 1500,
      destination_rows: 250,
      message: "Pipeline executed successfully. Transformed 250 rows in 1500ms. Wrote 250 rows to destination."
    })

    PipelineExecutionService.stub :new, mock_service do
      PipelineExecutionJob.perform_now(pipeline_run.id)
    end

    # Step 9: Verify execution results
    pipeline_run.reload
    pipeline.reload

    assert_equal "succeeded", pipeline_run.status
    assert_equal "succeeded", pipeline.status
    assert_not_nil pipeline_run.completed_at
    assert_not_nil pipeline.last_run_at
    assert_match(/Sources loaded: 2/, pipeline_run.logs)
    assert_match(/Transformation rows: 250/, pipeline_run.logs)

    # Step 10: View pipeline with updated status
    get pipeline_url(pipeline)
    assert_response :success
    assert_select ".inline-flex", text: "Succeeded"

    # Step 11: Edit the pipeline
    get edit_pipeline_url(pipeline)
    assert_response :success

    # Step 12: Update pipeline sources
    patch pipeline_url(pipeline), params: {
      pipeline: {
        source_connector_ids: [ @source1.id ],
        connector_tables: {
          @source1.id.to_s => { schema: "PUBLIC", table: "UPDATED_TABLE" }
        },
        write_disposition: "truncate_and_load"
      }
    }

    assert_redirected_to pipeline_url(pipeline)
    pipeline.reload

    assert_equal 1, pipeline.source_datasets.count
    assert_equal "truncate_and_load", pipeline.write_disposition

    # Step 13: Delete the pipeline
    assert_difference("Pipeline.count", -1) do
      assert_difference("PipelineRun.count", -1) do
        delete pipeline_url(pipeline)
      end
    end

    assert_redirected_to pipelines_url
    follow_redirect!
    # Flash messages use bg-success class for notices
    assert_select ".bg-success", text: /deleted/i
  end

  test "pipeline execution handles errors gracefully" do
    post sign_in_url, params: { email: @admin.email, password: "password123" }

    # Create pipeline
    post pipelines_url, params: {
      pipeline: {
        name: "Error Test Pipeline",
        transformation_sql: "SELECT * FROM nonexistent_table",
        source_connector_ids: [ @source1.id ],
        connector_tables: {
          @source1.id.to_s => { schema: "PUBLIC", table: "ERROR_TABLE" }
        }
      }
    }

    pipeline = Pipeline.last

    # Run pipeline
    post run_pipeline_url(pipeline)
    pipeline_run = pipeline.pipeline_runs.last

    # Simulate execution error
    mock_service = Minitest::Mock.new
    mock_service.expect(:execute, nil) do
      raise PipelineExecutionService::ExecutionError, "Table does not exist"
    end

    PipelineExecutionService.stub :new, mock_service do
      PipelineExecutionJob.perform_now(pipeline_run.id)
    end

    # Verify error handling
    pipeline_run.reload
    pipeline.reload

    assert_equal "failed", pipeline_run.status
    assert_equal "failed", pipeline.status
    assert_equal "Table does not exist", pipeline_run.error_message
    assert_match(/Pipeline execution failed/i, pipeline_run.logs)

    # View pipeline with error status
    get pipeline_url(pipeline)
    assert_response :success
    assert_select ".inline-flex", text: "Failed"
  end

  test "pipeline with dataset source executes successfully" do
    post sign_in_url, params: { email: @admin.email, password: "password123" }

    dataset = datasets(:sales_summary)

    # Create pipeline with dataset as source
    assert_difference("Pipeline.count", 1) do
      assert_difference("PipelineSource.count", 1) do
        post pipelines_url, params: {
          pipeline: {
            name: "Dataset Source Pipeline",
            description: "Pipeline that reads from a dataset",
            transformation_sql: "SELECT * FROM sales_summary WHERE total_revenue > 1000",
            source_dataset_ids: [ dataset.id, "" ],
            destination_connector_id: @destination.id,
            write_disposition: "append"
          }
        }
      end
    end

    pipeline = Pipeline.last

    # Verify pipeline created with dataset source
    assert_equal 1, pipeline.source_datasets.count
    assert_equal 0, pipeline.source_connectors.count
    assert_includes pipeline.source_datasets, dataset

    # Run the pipeline
    post run_pipeline_url(pipeline)
    pipeline_run = pipeline.pipeline_runs.last

    # Execute with dataset source
    mock_service = Minitest::Mock.new
    mock_service.expect(:execute, {
      success: true,
      sources_loaded: 1,
      transformation_rows: 150,
      execution_time_ms: 800,
      destination_rows: 150,
      message: "Pipeline executed successfully with dataset source"
    })

    PipelineExecutionService.stub :new, mock_service do
      PipelineExecutionJob.perform_now(pipeline_run.id)
    end

    # Verify execution results
    pipeline_run.reload
    assert_equal "succeeded", pipeline_run.status
    assert_match(/Sources loaded: 1/, pipeline_run.logs)
    assert_match(/Transformation rows: 150/, pipeline_run.logs)
  end

  test "pipeline without destination executes transformation only" do
    post sign_in_url, params: { email: @admin.email, password: "password123" }

    # Create pipeline without destination
    post pipelines_url, params: {
      pipeline: {
        name: "Transform Only Pipeline",
        transformation_sql: "SELECT COUNT(*) as total FROM production_snowflake",
        source_connector_ids: [ @source1.id ],
        connector_tables: {
          @source1.id.to_s => { schema: "PUBLIC", table: "TRANSFORM_TABLE" }
        },
        destination_connector_id: ""
      }
    }

    pipeline = Pipeline.last
    assert_nil pipeline.destination_connector

    # Run pipeline
    post run_pipeline_url(pipeline)
    pipeline_run = pipeline.pipeline_runs.last

    # Execute without destination
    mock_service = Minitest::Mock.new
    mock_service.expect(:execute, {
      success: true,
      sources_loaded: 1,
      transformation_rows: 1,
      execution_time_ms: 500,
      destination_rows: 0,
      message: "Pipeline executed successfully. Transformed 1 rows in 500ms. No destination configured."
    })

    PipelineExecutionService.stub :new, mock_service do
      PipelineExecutionJob.perform_now(pipeline_run.id)
    end

    pipeline_run.reload

    assert_equal "succeeded", pipeline_run.status
    assert_match(/No destination configured/, pipeline_run.logs)
    assert_match(/Destination rows written: 0/, pipeline_run.logs)
  end

  test "multiple concurrent pipeline runs" do
    post sign_in_url, params: { email: @admin.email, password: "password123" }

    # Create pipeline
    post pipelines_url, params: {
      pipeline: {
        name: "Concurrent Test Pipeline",
        transformation_sql: "SELECT * FROM production_snowflake",
        source_connector_ids: [ @source1.id ],
        connector_tables: {
          @source1.id.to_s => { schema: "PUBLIC", table: "CONCURRENT_TABLE" }
        }
      }
    }

    pipeline = Pipeline.last

    # Create multiple runs
    run1 = pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)
    run2 = pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)
    run3 = pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)

    assert_equal 3, pipeline.pipeline_runs.count

    # Execute runs sequentially (simulating queue processing)
    mock_service = Minitest::Mock.new
    3.times do
      mock_service.expect(:execute, {
        success: true,
        sources_loaded: 1,
        transformation_rows: 100,
        execution_time_ms: 1000,
        destination_rows: 0,
        message: "Success"
      })
    end

    PipelineExecutionService.stub :new, mock_service do
      [ run1, run2, run3 ].each do |run|
        PipelineExecutionJob.perform_now(run.id)
      end
    end

    # Verify all runs completed
    [ run1, run2, run3 ].each do |run|
      run.reload
      assert_equal "succeeded", run.status
      assert_not_nil run.completed_at
    end

    # View pipeline with run history
    get pipeline_url(pipeline)
    assert_response :success
    assert_select "h2", text: "Recent Runs"
  end

  test "viewer can view but not modify pipelines" do
    viewer = users(:viewer_user)
    post sign_in_url, params: { email: viewer.email, password: "password123" }

    # Create pipeline as admin first
    delete sign_out_url
    post sign_in_url, params: { email: @admin.email, password: "password123" }

    post pipelines_url, params: {
      pipeline: {
        name: "Viewer Test",
        transformation_sql: "SELECT 1",
        source_connector_ids: [ @source1.id ],
        connector_tables: {
          @source1.id.to_s => { schema: "PUBLIC", table: "VIEWER_TABLE" }
        }
      }
    }

    pipeline = Pipeline.last

    # Sign in as viewer
    delete sign_out_url
    post sign_in_url, params: { email: viewer.email, password: "password123" }

    # Can view
    get pipelines_url
    assert_response :success

    get pipeline_url(pipeline)
    assert_response :success

    # Cannot run (only admins can run pipelines)
    assert_no_difference("PipelineRun.count") do
      post run_pipeline_url(pipeline)
    end
    assert_redirected_to root_path
  end
end
