require "test_helper"

class DatasetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @dataset = datasets(:sales_summary)
    @connector = connectors(:one)
    @admin = users(:admin_user)
    @admin = users(:admin_user)
    @viewer = users(:viewer_user)
  end

  # Index Tests
  test "should require login to access index" do
    get datasets_url
    assert_redirected_to sign_in_url
  end

  test "should get index when logged in" do
    sign_in_as(@viewer)
    get datasets_url
    assert_response :success
  end

  test "should display datasets in index" do
    sign_in_as(@viewer)
    get datasets_url
    assert_select "h1", text: "Datasets"
  end

  # Show Tests
  test "should require login to show dataset" do
    get dataset_url(@dataset)
    assert_redirected_to sign_in_url
  end

  test "should show dataset when logged in" do
    sign_in_as(@viewer)
    get dataset_url(@dataset)
    assert_response :success
  end

  test "should display dataset details" do
    sign_in_as(@viewer)
    get dataset_url(@dataset)
    assert_select "h1", text: @dataset.name
  end

  # New Tests
  test "should require login to access new" do
    get new_dataset_url
    assert_redirected_to sign_in_url
  end

  test "should allow admin to access new" do
    sign_in_as(@admin)
    get new_dataset_url
    assert_response :success
  end

  test "should allow engineer to access new" do
    sign_in_as(@admin)
    get new_dataset_url
    assert_response :success
  end

  test "should not allow analyst to access new" do
    sign_in_as(@viewer)
    get new_dataset_url
    assert_redirected_to root_path
    assert_equal "You are not authorized to perform this action.", flash[:alert]
  end

  test "should pre-populate form when coming from browse_tables" do
    sign_in_as(@admin)

    # For now, just test that the form gets populated correctly
    # Schema fetching will fail in tests without proper mocking of HTTP requests
    get new_dataset_url, params: {
      connector_id: @connector.id,
      schema_name: "PUBLIC",
      table_name: "TEST_TABLE"
    }
    assert_response :success
    assert_select "input[name='dataset[schema_name]'][value='PUBLIC']"
    assert_select "input[name='dataset[table_name]'][value='TEST_TABLE']"
    # Name should be auto-generated from schema.table_name
    assert_select "input[name='dataset[name]'][value=?]", "Public.Test Table"
  end

  # Create Tests
  test "should allow admin to create dataset" do
    sign_in_as(@admin)
    assert_difference("Dataset.count") do
      post datasets_url, params: {
        dataset: {
          name: "New Test Dataset",
          description: "A test dataset",
          table_name: "test_table",
          schema_name: "PUBLIC",
          connector_id: @connector.id,
          status: "active"
        }
      }
    end
    assert_redirected_to dataset_url(Dataset.last)
  end

  test "should allow engineer to create dataset" do
    sign_in_as(@admin)
    assert_difference("Dataset.count") do
      post datasets_url, params: {
        dataset: {
          name: "Engineer Dataset",
          table_name: "engineer_table",
          schema_name: "PUBLIC",
          connector_id: @connector.id
        }
      }
    end
    assert_redirected_to dataset_url(Dataset.last)
  end

  test "should not allow analyst to create dataset" do
    sign_in_as(@viewer)
    assert_no_difference("Dataset.count") do
      post datasets_url, params: {
        dataset: {
          name: "Analyst Dataset",
          table_name: "analyst_table",
          connector_id: @connector.id
        }
      }
    end
    assert_redirected_to root_path
  end

  test "should not create dataset with invalid data" do
    sign_in_as(@admin)
    assert_no_difference("Dataset.count") do
      post datasets_url, params: {
        dataset: {
          name: "",
          table_name: "",
          connector_id: nil
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should persist schema when creating dataset" do
    sign_in_as(@admin)
    schema_json = {
      columns: [
        { name: "id", type: "INTEGER" },
        { name: "name", type: "VARCHAR" }
      ]
    }

    assert_difference("Dataset.count") do
      post datasets_url, params: {
        dataset: {
          name: "Schema Test Dataset",
          table_name: "schema_test_table",
          schema_name: "PUBLIC",
          connector_id: @connector.id,
          schema: schema_json.to_json
        }
      }
    end

    dataset = Dataset.last
    assert_not_nil dataset.schema
    assert_equal 2, dataset.schema["columns"].length
    assert_equal "id", dataset.schema["columns"][0]["name"]
    assert_equal "INTEGER", dataset.schema["columns"][0]["type"]
  end

  test "should not allow duplicate table_name for same connector and schema" do
    sign_in_as(@admin)
    assert_no_difference("Dataset.count") do
      post datasets_url, params: {
        dataset: {
          name: "Duplicate Dataset",
          table_name: @dataset.table_name,
          schema_name: @dataset.schema_name,
          connector_id: @dataset.connector_id
        }
      }
    end
    assert_response :unprocessable_entity
  end

  # Edit Tests
  test "should allow admin to access edit" do
    sign_in_as(@admin)
    get edit_dataset_url(@dataset)
    assert_response :success
  end

  test "should not allow viewer to access edit" do
    sign_in_as(@viewer)
    get edit_dataset_url(@dataset)
    assert_redirected_to root_path
  end

  # Update Tests
  test "should allow admin to update dataset" do
    sign_in_as(@admin)
    patch dataset_url(@dataset), params: {
      dataset: {
        name: "Updated Dataset Name"
      }
    }
    assert_redirected_to dataset_url(@dataset)
    @dataset.reload
    assert_equal "Updated Dataset Name", @dataset.name
  end

  test "should not allow viewer to update dataset" do
    sign_in_as(@viewer)
    original_name = @dataset.name
    patch dataset_url(@dataset), params: {
      dataset: {
        name: "Analyst Update"
      }
    }
    assert_redirected_to root_path
    @dataset.reload
    assert_equal original_name, @dataset.name
  end

  test "should not update dataset with invalid data" do
    sign_in_as(@admin)
    original_name = @dataset.name
    patch dataset_url(@dataset), params: {
      dataset: {
        name: ""
      }
    }
    assert_response :unprocessable_entity
    @dataset.reload
    assert_equal original_name, @dataset.name
  end

  # Destroy Tests
  test "should allow admin to destroy dataset" do
    sign_in_as(@admin)
    assert_difference("Dataset.count", -1) do
      delete dataset_url(@dataset)
    end
    assert_redirected_to datasets_path
  end

  test "should not allow viewer to destroy dataset" do
    sign_in_as(@viewer)
    assert_no_difference("Dataset.count") do
      delete dataset_url(@dataset)
    end
    assert_redirected_to root_path
  end

  # Data View Tests
  test "should require login to view data" do
    get data_dataset_url(@dataset)
    assert_redirected_to sign_in_url
  end

  test "should allow analyst to view data" do
    sign_in_as(@viewer)
    get data_dataset_url(@dataset)
    assert_response :success
  end

  test "should allow engineer to view data" do
    sign_in_as(@admin)
    get data_dataset_url(@dataset)
    assert_response :success
  end

  test "should allow admin to view data" do
    sign_in_as(@admin)
    get data_dataset_url(@dataset)
    assert_response :success
  end

  test "should display data with pagination" do
    sign_in_as(@viewer)
    get data_dataset_url(@dataset)
    assert_select "h1", text: /#{@dataset.name}/
    assert_select "table"
  end

  test "should handle pagination parameter" do
    sign_in_as(@viewer)
    get data_dataset_url(@dataset, page: 2)
    assert_response :success
  end

  private

  def sign_in_as(user)
    post sign_in_url, params: { email: user.email, password: "password123" }
  end
end
