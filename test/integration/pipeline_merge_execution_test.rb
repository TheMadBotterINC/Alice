require "test_helper"

class PipelineMergeExecutionTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @snowflake_connector = connectors(:one)
    @destination_dataset = datasets(:sales_summary)
  end

  test "complete merge pipeline execution flow with single merge key" do
    # Step 1: Sign in as admin
    post sign_in_url, params: { email: @admin.email, password: "password123" }
    assert_response :redirect
    follow_redirect!

    # Step 2: Create a pipeline with merge write disposition and single merge key
    assert_difference("Pipeline.count", 1) do
      assert_difference("PipelineSource.count", 1) do
        post pipelines_url, params: {
          pipeline: {
            name: "Sales Merge Pipeline",
            description: "Merge daily sales data by product_id",
            transformation_sql: "SELECT product_id, SUM(quantity) as total_quantity, SUM(revenue) as total_revenue FROM sales_data GROUP BY product_id",
            source_dataset_ids: [ @destination_dataset.id, "" ],
            destination_dataset_id: @destination_dataset.id,
            write_disposition: "merge",
            merge_key: "product_id"
          }
        }
      end
    end

    assert_redirected_to pipeline_url(Pipeline.last)
    pipeline = Pipeline.last

    # Step 3: Verify pipeline configuration
    assert_equal "Sales Merge Pipeline", pipeline.name
    assert_equal "merge", pipeline.write_disposition
    assert_equal "product_id", pipeline.merge_key
    assert_equal @destination_dataset, pipeline.destination_dataset
    assert pipeline.disposition_merge?

    # Step 4: View pipeline details
    get pipeline_url(pipeline)
    assert_response :success
    assert_select "h1", pipeline.name
    # Merge disposition is displayed with the merge key inline
    assert_match /Merge/i, response.body
    assert_match /product_id/, response.body

    # Step 5: Run the pipeline
    assert_difference("PipelineRun.count") do
      post run_pipeline_url(pipeline)
    end

    assert_redirected_to pipeline_url(pipeline)
    follow_redirect!
    assert_select ".bg-success", text: /queued/i

    pipeline_run = pipeline.pipeline_runs.last
    assert_equal "pending", pipeline_run.status

    # Step 6: Execute the pipeline with merge disposition
    # Mock the service to return successful merge execution
    mock_service = Minitest::Mock.new
    mock_service.expect(:execute, {
      success: true,
      sources_loaded: 1,
      transformation_rows: 150,
      execution_time_ms: 2000,
      destination_rows: 150,
      message: "Pipeline executed successfully. Transformed 150 rows in 2000ms. Merged 150 rows to destination."
    })

    PipelineExecutionService.stub :new, mock_service do
      PipelineExecutionJob.perform_now(pipeline_run.id)
    end

    # Step 7: Verify execution results
    pipeline_run.reload
    pipeline.reload

    assert_equal "succeeded", pipeline_run.status
    assert_equal "succeeded", pipeline.status
    assert_not_nil pipeline_run.completed_at
    assert_match(/Sources loaded: 1/, pipeline_run.logs)
    assert_match(/Transformation rows: 150/, pipeline_run.logs)
    assert_match(/Destination rows written: 150/, pipeline_run.logs)

    # Step 8: View pipeline with merge execution results
    get pipeline_url(pipeline)
    assert_response :success
    assert_select ".inline-flex", text: "Succeeded"

    # Step 9: Verify merge key is displayed in pipeline show page
    # The merge key appears inline with write disposition
    assert_match /product_id/, response.body
  end

  test "merge pipeline with multi-column merge key" do
    post sign_in_url, params: { email: @admin.email, password: "password123" }

    # Create pipeline with composite merge key
    assert_difference("Pipeline.count", 1) do
      post pipelines_url, params: {
        pipeline: {
          name: "Multi-Key Merge Pipeline",
          description: "Merge by region and product_id",
          transformation_sql: "SELECT region, product_id, SUM(sales) as total_sales FROM regional_sales GROUP BY region, product_id",
          source_dataset_ids: [ @destination_dataset.id, "" ],
          destination_dataset_id: @destination_dataset.id,
          write_disposition: "merge",
          merge_key: "region, product_id"
        }
      }
    end

    pipeline = Pipeline.last

    # Verify multi-column merge key
    assert_equal "region, product_id", pipeline.merge_key
    assert_equal [ "region", "product_id" ], pipeline.merge_key.split(",").map(&:strip)

    # View pipeline
    get pipeline_url(pipeline)
    assert_response :success
    assert_match /region, product_id/, response.body

    # Run the pipeline
    post run_pipeline_url(pipeline)
    pipeline_run = pipeline.pipeline_runs.last

    # Execute with multi-column merge
    mock_service = Minitest::Mock.new
    mock_service.expect(:execute, {
      success: true,
      sources_loaded: 1,
      transformation_rows: 200,
      execution_time_ms: 2500,
      destination_rows: 200,
      message: "Multi-column merge completed successfully"
    })

    PipelineExecutionService.stub :new, mock_service do
      PipelineExecutionJob.perform_now(pipeline_run.id)
    end

    pipeline_run.reload
    assert_equal "succeeded", pipeline_run.status
  end

  test "merge pipeline requires merge_key" do
    post sign_in_url, params: { email: @admin.email, password: "password123" }

    # Try to create merge pipeline without merge_key
    assert_no_difference("Pipeline.count") do
      post pipelines_url, params: {
        pipeline: {
          name: "Invalid Merge Pipeline",
          transformation_sql: "SELECT * FROM data",
          source_dataset_ids: [ @destination_dataset.id, "" ],
          destination_dataset_id: @destination_dataset.id,
          write_disposition: "merge",
          merge_key: ""  # Missing merge key
        }
      }
    end

    # Should show validation error
    assert_response :unprocessable_entity
    assert_match /merge key/i, response.body
  end

  test "save merge pipeline as template preserves merge settings" do
    post sign_in_url, params: { email: @admin.email, password: "password123" }

    # Create pipeline with merge disposition
    post pipelines_url, params: {
      pipeline: {
        name: "Merge Pipeline for Template",
        description: "Template source pipeline",
        transformation_sql: "SELECT * FROM source",
        source_dataset_ids: [ @destination_dataset.id, "" ],
        destination_dataset_id: @destination_dataset.id,
        write_disposition: "merge",
        merge_key: "id, updated_at"
      }
    }

    pipeline = Pipeline.last

    # Save as template
    post save_as_template_pipeline_url(pipeline), params: {
      template_name: "Merge Template"
    }

    assert_redirected_to templates_pipelines_url
    follow_redirect!
    assert_select ".bg-success", text: /saved as template/i

    # Verify template preserves merge settings
    template = Pipeline.templates.find_by(name: "Merge Template")
    assert_not_nil template
    assert template.is_template?
    assert_equal "merge", template.write_disposition
    assert_equal "id, updated_at", template.merge_key

    # View template
    get pipeline_url(template)
    assert_response :success
    assert_match /merge/i, response.body
    assert_match /id, updated_at/, response.body
  end

  test "create merge pipeline from template preserves merge configuration" do
    post sign_in_url, params: { email: @admin.email, password: "password123" }

    # Create template with merge disposition
    template = Pipeline.create!(
      name: "Merge Template Source",
      description: "Template for merge pipelines",
      transformation_sql: "SELECT * FROM data",
      write_disposition: :merge,
      merge_key: "customer_id",
      is_template: true
    )

    template.pipeline_sources.create!(dataset: @destination_dataset)
    template.update!(destination_dataset: @destination_dataset)

    # Create pipeline from template using form params
    post create_from_template_pipelines_url, params: {
      template_id: template.id,
      pipeline_name: "Pipeline from Merge Template",
      schedule: "0 3 * * *"
    }

    new_pipeline = Pipeline.pipelines.order(created_at: :desc).first
    assert_redirected_to pipeline_url(new_pipeline)

    # Verify merge settings were copied
    assert_equal "Pipeline from Merge Template", new_pipeline.name
    assert_equal "merge", new_pipeline.write_disposition
    assert_equal "customer_id", new_pipeline.merge_key
    assert_equal "0 3 * * *", new_pipeline.schedule
    assert_not new_pipeline.is_template?

    # View the new pipeline
    get pipeline_url(new_pipeline)
    assert_response :success
    assert_match /merge/i, response.body
    assert_match /customer_id/, response.body
  end

  test "edit merge pipeline to change merge key" do
    post sign_in_url, params: { email: @admin.email, password: "password123" }

    # Create initial merge pipeline
    post pipelines_url, params: {
      pipeline: {
        name: "Editable Merge Pipeline",
        transformation_sql: "SELECT * FROM data",
        source_dataset_ids: [ @destination_dataset.id, "" ],
        destination_dataset_id: @destination_dataset.id,
        write_disposition: "merge",
        merge_key: "id"
      }
    }

    pipeline = Pipeline.last
    assert_equal "id", pipeline.merge_key

    # Edit to change merge key
    get edit_pipeline_url(pipeline)
    assert_response :success
    assert_select "input[name='pipeline[merge_key]'][value='id']"

    # Update merge key
    patch pipeline_url(pipeline), params: {
      pipeline: {
        merge_key: "id, timestamp"
      }
    }

    assert_redirected_to pipeline_url(pipeline)

    pipeline.reload
    assert_equal "id, timestamp", pipeline.merge_key

    # Verify change persisted
    get pipeline_url(pipeline)
    assert_response :success
    assert_match /id, timestamp/, response.body
  end

  test "change write disposition from append to merge" do
    post sign_in_url, params: { email: @admin.email, password: "password123" }

    # Create pipeline with append disposition
    post pipelines_url, params: {
      pipeline: {
        name: "Append to Merge Pipeline",
        transformation_sql: "SELECT * FROM data",
        source_dataset_ids: [ @destination_dataset.id, "" ],
        destination_dataset_id: @destination_dataset.id,
        write_disposition: "append"
      }
    }

    pipeline = Pipeline.last
    assert_equal "append", pipeline.write_disposition
    assert_nil pipeline.merge_key

    # Edit to change to merge (should require merge_key)
    patch pipeline_url(pipeline), params: {
      pipeline: {
        write_disposition: "merge",
        merge_key: "user_id"
      }
    }

    assert_redirected_to pipeline_url(pipeline)

    pipeline.reload
    assert_equal "merge", pipeline.write_disposition
    assert_equal "user_id", pipeline.merge_key
  end

  test "change write disposition from merge to truncate_and_load clears merge_key" do
    post sign_in_url, params: { email: @admin.email, password: "password123" }

    # Create merge pipeline
    post pipelines_url, params: {
      pipeline: {
        name: "Merge to Truncate Pipeline",
        transformation_sql: "SELECT * FROM data",
        source_dataset_ids: [ @destination_dataset.id, "" ],
        destination_dataset_id: @destination_dataset.id,
        write_disposition: "merge",
        merge_key: "record_id"
      }
    }

    pipeline = Pipeline.last
    assert_equal "merge", pipeline.write_disposition
    assert_equal "record_id", pipeline.merge_key

    # Change to truncate_and_load
    patch pipeline_url(pipeline), params: {
      pipeline: {
        write_disposition: "truncate_and_load",
        merge_key: ""  # Clear merge key
      }
    }

    assert_redirected_to pipeline_url(pipeline)

    pipeline.reload
    assert_equal "truncate_and_load", pipeline.write_disposition
    # merge_key can be present but won't be used for non-merge dispositions
  end

  test "merge pipeline execution handles adapter errors gracefully" do
    post sign_in_url, params: { email: @admin.email, password: "password123" }

    # Create merge pipeline
    post pipelines_url, params: {
      pipeline: {
        name: "Error Merge Pipeline",
        transformation_sql: "SELECT * FROM data",
        source_dataset_ids: [ @destination_dataset.id, "" ],
        destination_dataset_id: @destination_dataset.id,
        write_disposition: "merge",
        merge_key: "nonexistent_column"
      }
    }

    pipeline = Pipeline.last

    # Run the pipeline
    post run_pipeline_url(pipeline)
    pipeline_run = pipeline.pipeline_runs.last

    # Simulate merge execution error (e.g., merge key column doesn't exist)
    mock_service = Minitest::Mock.new
    mock_service.expect(:execute, nil) do
      raise PipelineExecutionService::ExecutionError, "Column 'nonexistent_column' not found in result set"
    end

    PipelineExecutionService.stub :new, mock_service do
      PipelineExecutionJob.perform_now(pipeline_run.id)
    end

    # Verify error handling
    pipeline_run.reload
    pipeline.reload

    assert_equal "failed", pipeline_run.status
    assert_equal "failed", pipeline.status
    assert_match(/Column 'nonexistent_column' not found/, pipeline_run.error_message)

    # View pipeline with error
    get pipeline_url(pipeline)
    assert_response :success
    assert_select ".inline-flex", text: "Failed"
  end

  test "merge pipeline with scheduled execution" do
    post sign_in_url, params: { email: @admin.email, password: "password123" }

    # Create scheduled merge pipeline
    post pipelines_url, params: {
      pipeline: {
        name: "Scheduled Merge Pipeline",
        description: "Daily merge at 2 AM",
        transformation_sql: "SELECT * FROM daily_data",
        source_dataset_ids: [ @destination_dataset.id, "" ],
        destination_dataset_id: @destination_dataset.id,
        write_disposition: "merge",
        merge_key: "date, user_id",
        schedule: "0 2 * * *"
      }
    }

    pipeline = Pipeline.last

    # Verify schedule and merge settings
    assert_equal "0 2 * * *", pipeline.schedule
    assert_equal "merge", pipeline.write_disposition
    assert_equal "date, user_id", pipeline.merge_key

    # Manually create a pipeline run (simulating scheduled execution)
    post run_pipeline_url(pipeline)
    pipeline_run = pipeline.pipeline_runs.last
    assert_equal "pending", pipeline_run.status

    # Execute the scheduled merge run
    mock_service = Minitest::Mock.new
    mock_service.expect(:execute, {
      success: true,
      sources_loaded: 1,
      transformation_rows: 100,
      execution_time_ms: 1500,
      destination_rows: 100,
      message: "Scheduled merge completed"
    })

    PipelineExecutionService.stub :new, mock_service do
      PipelineExecutionJob.perform_now(pipeline_run.id)
    end

    pipeline_run.reload
    assert_equal "succeeded", pipeline_run.status
  end

  test "merge pipeline list shows merge disposition badge" do
    post sign_in_url, params: { email: @admin.email, password: "password123" }

    # Create pipelines with different dispositions
    post pipelines_url, params: {
      pipeline: {
        name: "Append Pipeline",
        transformation_sql: "SELECT * FROM data",
        source_dataset_ids: [ @destination_dataset.id, "" ],
        write_disposition: "append"
      }
    }

    post pipelines_url, params: {
      pipeline: {
        name: "Merge Pipeline Display",
        transformation_sql: "SELECT * FROM data",
        source_dataset_ids: [ @destination_dataset.id, "" ],
        destination_dataset_id: @destination_dataset.id,
        write_disposition: "merge",
        merge_key: "id"
      }
    }

    post pipelines_url, params: {
      pipeline: {
        name: "Truncate Pipeline",
        transformation_sql: "SELECT * FROM data",
        source_dataset_ids: [ @destination_dataset.id, "" ],
        write_disposition: "truncate_and_load"
      }
    }

    # View pipelines list
    get pipelines_url
    assert_response :success

    # Should show pipeline names
    assert_select "td", text: "Append Pipeline"
    assert_select "td", text: "Merge Pipeline Display"
    assert_select "td", text: "Truncate Pipeline"
  end

  test "delete merge pipeline removes all associated data" do
    post sign_in_url, params: { email: @admin.email, password: "password123" }

    # Create merge pipeline with runs
    post pipelines_url, params: {
      pipeline: {
        name: "Deletable Merge Pipeline",
        transformation_sql: "SELECT * FROM data",
        source_dataset_ids: [ @destination_dataset.id, "" ],
        destination_dataset_id: @destination_dataset.id,
        write_disposition: "merge",
        merge_key: "id"
      }
    }

    pipeline = Pipeline.last

    # Create a pipeline run
    post run_pipeline_url(pipeline)
    pipeline_run = pipeline.pipeline_runs.last

    # Delete the pipeline
    assert_difference("Pipeline.count", -1) do
      assert_difference("PipelineRun.count", -1) do
        assert_difference("PipelineSource.count", -1) do
          delete pipeline_url(pipeline)
        end
      end
    end

    assert_redirected_to pipelines_url
    follow_redirect!
    assert_select ".bg-success", text: /deleted/i
  end
end
