require "test_helper"
require "webmock/minitest"

class ConnectorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @connector = connectors(:one)
    @admin = users(:admin_user)
    @viewer = users(:viewer_user)
  end

  # Index Tests
  test "should require login to access index" do
    get connectors_url
    assert_redirected_to sign_in_url
  end

  test "should get index when logged in as admin" do
    sign_in_as(@admin)
    get connectors_url
    assert_response :success
  end

  test "should get index when logged in as viewer" do
    sign_in_as(@viewer)
    get connectors_url
    assert_response :success
  end

  # Show Tests
  test "should require login to show connector" do
    get connector_url(@connector)
    assert_redirected_to sign_in_url
  end

  test "should show connector when logged in as admin" do
    sign_in_as(@admin)
    get connector_url(@connector)
    assert_response :success
  end

  test "should show connector when logged in as viewer" do
    sign_in_as(@viewer)
    get connector_url(@connector)
    assert_response :success
  end

  # New Tests
  test "should require login to access new" do
    get new_connector_url
    assert_redirected_to sign_in_url
  end

  test "should allow admin to access new" do
    sign_in_as(@admin)
    get new_connector_url
    assert_response :success
  end

  test "should not allow viewer to access new" do
    sign_in_as(@viewer)
    get new_connector_url
    assert_redirected_to root_path
    assert_equal "You are not authorized to perform this action.", flash[:alert]
  end

  # Create Tests
  test "should allow admin to create connector" do
    sign_in_as(@admin)
    assert_difference("Connector.count") do
      post connectors_url, params: {
        connector: {
          name: "New Test Connector",
          connector_type: "snowflake",
          config: {
            account: "test_account",
            username: "test_user",
            private_key: "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC\n-----END PRIVATE KEY-----",
            database: "test_db",
            warehouse: "test_wh"
          }
        }
      }
    end
    assert_redirected_to connector_url(Connector.last)
  end

  test "should not allow viewer to create connector" do
    sign_in_as(@viewer)
    assert_no_difference("Connector.count") do
      post connectors_url, params: {
        connector: {
          name: "Test Connector",
          connector_type: "snowflake",
          config: {}
        }
      }
    end
    assert_redirected_to root_path
  end

  test "should not create connector with invalid data" do
    sign_in_as(@admin)
    assert_no_difference("Connector.count") do
      post connectors_url, params: {
        connector: {
          name: "",
          connector_type: "snowflake",
          config: {}
        }
      }
    end
    assert_response :unprocessable_entity
  end

  # Edit Tests
  test "should allow admin to access edit" do
    sign_in_as(@admin)
    get edit_connector_url(@connector)
    assert_response :success
  end

  test "should not allow viewer to access edit" do
    sign_in_as(@viewer)
    get edit_connector_url(@connector)
    assert_redirected_to root_path
  end

  # Update Tests
  test "should allow admin to update connector" do
    sign_in_as(@admin)
    patch connector_url(@connector), params: {
      connector: {
        name: "Updated Name"
      }
    }
    assert_redirected_to connector_url(@connector)
    @connector.reload
    assert_equal "Updated Name", @connector.name
  end

  test "should not allow viewer to update connector" do
    sign_in_as(@viewer)
    original_name = @connector.name
    patch connector_url(@connector), params: {
      connector: {
        name: "Updated Name"
      }
    }
    assert_redirected_to root_path
    @connector.reload
    assert_equal original_name, @connector.name
  end

  # Destroy Tests
  test "should allow admin to destroy connector" do
    sign_in_as(@admin)
    # Use connector :three which doesn't have datasets or pipelines
    deletable_connector = connectors(:three)
    assert_difference("Connector.count", -1) do
      delete connector_url(deletable_connector)
    end
    assert_redirected_to connectors_path
  end

  test "should not allow viewer to destroy connector" do
    sign_in_as(@viewer)
    assert_no_difference("Connector.count") do
      delete connector_url(@connector)
    end
    assert_redirected_to root_path
  end

  # Test Connection Tests
  test "should allow admin to test connection" do
    sign_in_as(@admin)

    # Mock the Snowflake API calls
    statement_handle = "test-handle"
    stub_request(:post, "https://prod_account.snowflakecomputing.com/api/v2/statements")
      .to_return(status: 200, body: { statementHandle: statement_handle }.to_json)

    stub_request(:get, "https://prod_account.snowflakecomputing.com/api/v2/statements/#{statement_handle}")
      .to_return(status: 200, body: { status: "success" }.to_json)

    stub_request(:get, "https://prod_account.snowflakecomputing.com/api/v2/statements/#{statement_handle}/result")
      .to_return(
        status: 200,
        body: {
          data: [ [ 1 ] ],
          resultSetMetaData: { rowType: [ { name: "test" } ] }
        }.to_json
      )

    post test_connection_connector_url(@connector)
    assert_redirected_to connector_url(@connector)
    assert_not_nil flash[:notice]

    WebMock.reset!
  end

  private

  def sign_in_as(user)
    post sign_in_url, params: { email: user.email, password: "password123" }
  end
end
