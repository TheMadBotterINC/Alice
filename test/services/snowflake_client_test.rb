require "test_helper"

class SnowflakeClientTest < ActiveSupport::TestCase
  # Disable fixtures for this test file since we don't need database records
  self.use_transactional_tests = false

  setup do
    @config = {
      account: "test_account",
      username: "test_user",
      private_key: generate_test_private_key,
      warehouse: "test_warehouse",
      database: "test_database",
      schema: "test_schema"
    }
    @client = SnowflakeClient.new(**@config)
  end

  teardown do
    @client&.close
  end

  # Initialization tests
  test "initializes with valid config" do
    assert_not_nil @client
    assert_equal "test_account", @client.account
    assert_equal "test_user", @client.username
  end

  test "raises error when missing required config" do
    assert_raises(ArgumentError) do
      SnowflakeClient.new(account: "test") # Missing other required params
    end
  end

  test "raises error when account is missing" do
    invalid_config = @config.except(:account)
    assert_raises(ArgumentError) do
      SnowflakeClient.new(**invalid_config)
    end
  end

  # Authentication tests
  test "authenticate returns valid JWT token" do
    token = @client.send(:authenticate!)

    assert_not_nil token
    assert_kind_of String, token
    # JWT tokens have 3 parts separated by dots
    assert_equal 3, token.split(".").length
  end

  test "authenticate caches token" do
    token1 = @client.send(:authenticate!)
    token2 = @client.send(:authenticate!)

    assert_equal token1, token2
  end

  test "authenticate raises error with invalid private key" do
    bad_config = @config.merge(private_key: "invalid key")
    bad_client = SnowflakeClient.new(**bad_config)

    assert_raises(SnowflakeClient::AuthenticationError) do
      bad_client.send(:authenticate!)
    end
  end

  # Query execution tests
  test "execute_query submits query and returns results" do
    stub_query_submission

    result = @client.execute_query("SELECT * FROM test_table")

    assert_not_nil result
    assert_kind_of Array, result
    assert_equal 2, result.length
    assert_equal "Alice", result[0]["NAME"]
    assert_equal "Bob", result[1]["NAME"]
  end

  test "execute_query handles async query with polling" do
    stub_query_submission_async
    stub_query_status_running
    stub_query_status_complete
    stub_query_results

    result = @client.execute_query("SELECT COUNT(*) FROM large_table")

    assert_not_nil result
    assert_kind_of Array, result
  end

  test "execute_query times out after max polling attempts" do
    stub_query_submission_async
    stub_query_status_running(times: 100)

    assert_raises(SnowflakeClient::QueryTimeoutError) do
      @client.execute_query("SELECT * FROM test_table", timeout: 1)
    end
  end

  test "execute_query raises error on query failure" do
    stub_query_submission_async
    stub_query_status_failed

    assert_raises(SnowflakeClient::QueryExecutionError) do
      @client.execute_query("SELECT * FROM nonexistent_table")
    end
  end

  test "execute_query handles empty result set" do
    stub_request(:post, "https://test_account.snowflakecomputing.com/api/v2/statements")
      .to_return(
        status: 200,
        body: {
          statementHandle: "query_123",
          statementStatusUrl: "/api/v2/statements/query_123",
          resultSetMetaData: {
            rowType: []
          },
          data: []
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.execute_query("SELECT * FROM test_table WHERE 1=0")

    assert_equal 0, result.length
    assert_equal [], result
  end

  # Result parsing tests
  test "parse_results handles various data types" do
    stub_request(:post, "https://test_account.snowflakecomputing.com/api/v2/statements")
      .to_return(
        status: 200,
        body: {
          statementHandle: "query_123",
          resultSetMetaData: {
            rowType: [
              { name: "ID", type: "FIXED" },
              { name: "NAME", type: "TEXT" },
              { name: "PRICE", type: "REAL" },
              { name: "ACTIVE", type: "BOOLEAN" }
            ]
          },
          data: [
            [ 1, "Test", 99.99, true ]
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.execute_query("SELECT * FROM test_table")

    row = result.first
    assert_kind_of Integer, row["ID"]
    assert_kind_of String, row["NAME"]
    assert_kind_of Float, row["PRICE"]
    assert [ true, false ].include?(row["ACTIVE"])
  end

  test "parse_results handles null values" do
    stub_request(:post, "https://test_account.snowflakecomputing.com/api/v2/statements")
      .to_return(
        status: 200,
        body: {
          statementHandle: "query_123",
          resultSetMetaData: {
            rowType: [
              { name: "ID", type: "FIXED" },
              { name: "NULLABLE_FIELD", type: "TEXT" }
            ]
          },
          data: [
            [ 1, nil ]
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.execute_query("SELECT * FROM test_table")

    assert result.first["NULLABLE_FIELD"].nil?
  end

  # Connection management tests
  test "close resets memoized token" do
    # Generate a token
    @client.send(:authenticate!)
    assert_not_nil @client.instance_variable_get(:@jwt_token), "Token should exist after authentication"

    # Close should clear the token
    @client.close

    # Verify token was cleared - this is the actual test
    token_after_close = @client.instance_variable_get(:@jwt_token)
    assert_nil token_after_close, "Token should be nil after close, but got: #{token_after_close&.slice(0, 50)}..."
  end

  test "close resets http client" do
    @client.close
    assert_nil @client.instance_variable_get(:@http_client)
  end

  test "close can be called multiple times safely" do
    assert_nothing_raised do
      @client.close
      @client.close
      @client.close
    end
  end

  # Error handling tests
  test "handles network errors gracefully" do
    stub_network_error

    assert_raises(SnowflakeClient::ConnectionError) do
      @client.execute_query("SELECT 1")
    end
  end

  test "handles malformed JSON response" do
    stub_malformed_json_response

    assert_raises(SnowflakeClient::ResponseParseError) do
      @client.execute_query("SELECT 1")
    end
  end

  private

  def generate_test_private_key
    # Generate a temporary RSA key for testing
    OpenSSL::PKey::RSA.new(2048).to_pem
  end

  def stub_query_submission
    stub_request(:post, "https://test_account.snowflakecomputing.com/api/v2/statements")
      .to_return(
        status: 200,
        body: {
          statementHandle: "query_123",
          statementStatusUrl: "/api/v2/statements/query_123",
          resultSetMetaData: {
            rowType: [
              { name: "ID", type: "FIXED" },
              { name: "NAME", type: "TEXT" }
            ]
          },
          data: [
            [ 1, "Alice" ],
            [ 2, "Bob" ]
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_query_submission_async
    stub_request(:post, "https://test_account.snowflakecomputing.com/api/v2/statements")
      .to_return(
        status: 200,
        body: {
          statementHandle: "query_async_123",
          statementStatusUrl: "/api/v2/statements/query_async_123",
          status: "running"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_query_status_complete(times: 1)
    stub_request(:get, "https://test_account.snowflakecomputing.com/api/v2/statements/query_async_123")
      .to_return(
        status: 200,
        body: {
          statementHandle: "query_async_123",
          status: "success",
          statementStatusUrl: "/api/v2/statements/query_async_123"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      ).times(times)
  end

  def stub_query_status_running(times: 1)
    stub_request(:get, "https://test_account.snowflakecomputing.com/api/v2/statements/query_async_123")
      .to_return(
        status: 200,
        body: {
          statementHandle: "query_async_123",
          status: "running"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      ).times(times)
  end

  def stub_query_status_failed
    stub_request(:get, "https://test_account.snowflakecomputing.com/api/v2/statements/query_async_123")
      .to_return(
        status: 200,
        body: {
          statementHandle: "query_async_123",
          status: "failed",
          message: "Table does not exist"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_query_results
    stub_request(:get, "https://test_account.snowflakecomputing.com/api/v2/statements/query_async_123/result")
      .to_return(
        status: 200,
        body: {
          statementHandle: "query_async_123",
          resultSetMetaData: {
            rowType: [
              { name: "ID", type: "FIXED" },
              { name: "NAME", type: "TEXT" }
            ]
          },
          data: [
            [ 1, "Alice" ],
            [ 2, "Bob" ]
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_query_results_empty
    stub_request(:get, "https://test_account.snowflakecomputing.com/api/v2/statements/query_123/result")
      .to_return(
        status: 200,
        body: {
          statementHandle: "query_123",
          resultSetMetaData: {
            rowType: []
          },
          data: []
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_query_results_with_types
    stub_request(:get, "https://test_account.snowflakecomputing.com/api/v2/statements/query_123/result")
      .to_return(
        status: 200,
        body: {
          statementHandle: "query_123",
          resultSetMetaData: {
            rowType: [
              { name: "ID", type: "FIXED" },
              { name: "NAME", type: "TEXT" },
              { name: "PRICE", type: "REAL" },
              { name: "ACTIVE", type: "BOOLEAN" }
            ]
          },
          data: [
            [ 1, "Test", 99.99, true ]
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_query_results_with_nulls
    stub_request(:get, "https://test_account.snowflakecomputing.com/api/v2/statements/query_123/result")
      .to_return(
        status: 200,
        body: {
          statementHandle: "query_123",
          resultSetMetaData: {
            rowType: [
              { name: "ID", type: "FIXED" },
              { name: "NULLABLE_FIELD", type: "TEXT" }
            ]
          },
          data: [
            [ 1, nil ]
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_network_error
    stub_request(:post, "https://test_account.snowflakecomputing.com/api/v2/statements")
      .to_timeout
  end

  def stub_malformed_json_response
    stub_request(:post, "https://test_account.snowflakecomputing.com/api/v2/statements")
      .to_return(
        status: 200,
        body: "not json",
        headers: { "Content-Type" => "application/json" }
      )
  end
end
