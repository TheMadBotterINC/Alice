# Snowflake REST API client
# Uses Snowflake's SQL REST API for query execution
# Reference: https://docs.snowflake.com/en/developer-guide/sql-api/reference
#
# Note: Snowflake SQL API requires key-pair authentication or OAuth.
# This implementation supports both:
# - Key-pair authentication (preferred): requires private_key
# - Fallback to password auth via session API (for legacy connectors)

require "jwt"
require "openssl"
require "digest"
require "base64"

class SnowflakeClient
  class AuthenticationError < StandardError; end
  class QueryError < StandardError; end
  class QueryExecutionError < QueryError; end
  class QueryTimeoutError < QueryError; end
  class ResponseParseError < QueryError; end
  class ConnectionError < StandardError; end

  attr_reader :account, :username, :private_key, :database, :warehouse, :schema, :role

  def initialize(account:, username:, private_key:, database:, warehouse:, schema: "PUBLIC", role: nil)
    @account = account
    @username = username
    @private_key = private_key
    @database = database
    @warehouse = warehouse
    @schema = schema
    @role = role
    @jwt_token = nil
    @token_expires_at = nil

    validate_config!
  end

  # Execute a SQL query and return results
  # @param sql [String] SQL query to execute
  # @param timeout [Integer] Query timeout in seconds
  # @return [Array<Hash>] Array of result rows as hashes
  def execute_query(sql, timeout: 300)
    query_start = Time.current
    Rails.logger.info("[SnowflakeClient] ⏱️  Starting query execution at #{query_start}")
    Rails.logger.info("[SnowflakeClient] Executing query: #{sql.truncate(100)}")

    submit_start = Time.current
    response_data = submit_query(sql, timeout: timeout)
    submit_duration = Time.current - submit_start
    Rails.logger.info("[SnowflakeClient] ⏱️  Query submission took #{submit_duration.round(2)}s")

    # Check if results are already in the response (synchronous execution)
    if response_data["data"]
      parse_start = Time.current
      results = parse_results(response_data)
      parse_duration = Time.current - parse_start
      total_duration = Time.current - query_start

      Rails.logger.info("[SnowflakeClient] Query completed synchronously")
      Rails.logger.info("[SnowflakeClient] ⏱️  Result parsing took #{parse_duration.round(2)}s")
      Rails.logger.info("[SnowflakeClient] ⏱️  Total execution time: #{total_duration.round(2)}s")
      return results
    end

    # Otherwise, poll for completion (asynchronous execution)
    statement_handle = response_data["statementHandle"]
    Rails.logger.info("[SnowflakeClient] Query running asynchronously, statement: #{statement_handle}")

    poll_start = Time.current
    wait_for_query_completion(statement_handle, timeout: timeout)
    poll_duration = Time.current - poll_start
    Rails.logger.info("[SnowflakeClient] ⏱️  Polling for completion took #{poll_duration.round(2)}s")

    fetch_start = Time.current
    results = fetch_query_results(statement_handle)
    fetch_duration = Time.current - fetch_start
    total_duration = Time.current - query_start

    Rails.logger.info("[SnowflakeClient] ⏱️  Fetching results took #{fetch_duration.round(2)}s")
    Rails.logger.info("[SnowflakeClient] ⏱️  Total execution time: #{total_duration.round(2)}s")
    results
  rescue Faraday::Error => e
    raise ConnectionError, "Connection error: #{e.message}"
  end

  # Test the connection
  # @return [Boolean] true if connection is successful
  def test_connection
    execute_query("SELECT 1 AS test")
    true
  rescue => e
    Rails.logger.error("[SnowflakeClient] Connection test failed: #{e.message}")
    false
  end

  # Get schema information for a table
  # @param table_name [String] Name of the table
  # @return [Array<Hash>] Array of column definitions
  def describe_table(table_name)
    sql = "DESC TABLE #{database}.#{schema}.#{table_name}"
    results = execute_query(sql)

    results.map do |row|
      {
        name: row["name"],
        type: row["type"],
        nullable: row["null?"] == "Y",
        default: row["default"],
        primary_key: row["primary key"] == "Y"
      }
    end
  end

  # Close HTTP client connection to release resources
  def close
    if @http_client
      Rails.logger.info("[SnowflakeClient] Closing HTTP client connection")
      begin
        # Close the Faraday connection if it has a close method
        @http_client.close if @http_client.respond_to?(:close)
      rescue => e
        Rails.logger.warn("[SnowflakeClient] Error closing HTTP client: #{e.message}")
      end
    end

    # Always clear tokens and client, regardless of whether http_client exists
    @http_client = nil
    @jwt_token = nil
    @token_expires_at = nil
  end

  private

  def validate_config!
    required = { account: @account, username: @username,
                 database: @database, warehouse: @warehouse, private_key: @private_key }
    missing = required.select { |k, v| v.nil? || v.to_s.empty? }

    if missing.any?
      raise ArgumentError, "Missing required config: #{missing.keys.join(', ')}"
    end
  end

  # Authenticate - generate JWT token for key-pair auth
  def authenticate!
    generate_jwt_token
  end

  # Generate JWT token for key-pair authentication
  def generate_jwt_token
    Rails.logger.info("[SnowflakeClient] Generating JWT token for key-pair authentication")

    # Parse the private key
    # Pass nil as passphrase to handle unencrypted keys without prompting
    begin
      rsa_key = OpenSSL::PKey::RSA.new(@private_key, nil)
    rescue OpenSSL::PKey::RSAError => e
      # Try without passphrase parameter (for encrypted keys user must decrypt first)
      begin
        rsa_key = OpenSSL::PKey::RSA.new(@private_key)
      rescue OpenSSL::PKey::RSAError
        raise AuthenticationError, "Invalid private key: #{e.message}. Ensure key is in PEM format and unencrypted."
      end
    end

    # Generate public key fingerprint (Base64 encoded, as Snowflake expects)
    public_key_der = rsa_key.public_key.to_der
    public_key_fp = "SHA256:" + Base64.strict_encode64(Digest::SHA256.digest(public_key_der))

    # Normalize account identifier (remove region info unless .global)
    normalized_account = normalize_account_identifier(@account)

    # Build qualified username
    qualified_username = "#{normalized_account.upcase}.#{@username.upcase}"

    # JWT payload
    now = Time.now.utc
    lifetime_seconds = 59 * 60 # 59 minutes (max is 60)

    payload = {
      iss: "#{qualified_username}.#{public_key_fp}",
      sub: qualified_username,
      iat: now.to_i,
      exp: (now + lifetime_seconds).to_i
    }

    # Generate JWT
    @jwt_token = JWT.encode(payload, rsa_key, "RS256")
    @token_expires_at = Time.current + lifetime_seconds.seconds

    Rails.logger.info("[SnowflakeClient] Successfully generated JWT token")
    @jwt_token
  rescue => e
    Rails.logger.error("[SnowflakeClient] JWT generation failed: #{e.message}")
    raise AuthenticationError, "Failed to generate JWT: #{e.message}"
  end

  # Normalize account identifier per Snowflake requirements
  def normalize_account_identifier(account)
    return account if account.include?(".global")

    # For organization-account format (e.g., "orgname-accountname"), keep as is
    # For account locator with region (e.g., "xy12345.us-east-1"), remove region
    if account.include?(".")
      # Has region info, take only the account part
      account.split(".").first
    else
      # No region info, use as is (including hyphens for org-account format)
      account
    end
  end

  # Check if we have a valid token
  def authenticated?
    @jwt_token && @token_expires_at && @token_expires_at > Time.current
  end

  # Ensure we have a valid token, authenticate if needed
  def ensure_authenticated!
    authenticate! unless authenticated?
  end

  # Submit a SQL statement for execution
  # Returns the full response data which may include results for fast queries
  def submit_query(sql, timeout:)
    ensure_authenticated!

    response = http_client.post(api_endpoint) do |req|
      req.headers["Content-Type"] = "application/json"
      req.headers["Accept"] = "application/json"
      req.headers["Authorization"] = auth_header
      req.body = {
        statement: sql,
        timeout: timeout,
        database: database,
        schema: schema,
        warehouse: warehouse,
        role: role
      }.compact.to_json
    end

    if !response.success?
      Rails.logger.error("[SnowflakeClient] Query submit failed with status #{response.status}: #{response.body}")
    end

    handle_response_errors(response)

    data = JSON.parse(response.body)
    statement_handle = data["statementHandle"]

    Rails.logger.info("[SnowflakeClient] Query submitted, statement handle: #{statement_handle}")
    Rails.logger.debug("[SnowflakeClient] Submit response has data: #{data['data'].present?}")

    data  # Return full response data
  rescue JSON::ParserError => e
    raise ResponseParseError, "Invalid JSON response: #{e.message}"
  end

  # Wait for query to complete
  def wait_for_query_completion(statement_handle, timeout:)
    start_time = Time.current
    poll_interval = 1 # Start with 1 second
    max_poll_interval = 10 # Max 10 seconds
    poll_count = 0

    Rails.logger.info("[SnowflakeClient] 🔄 Starting polling loop for statement: #{statement_handle}")

    loop do
      elapsed = Time.current - start_time
      if elapsed > timeout
        raise QueryTimeoutError, "Query timed out after #{timeout} seconds (#{poll_count} polls)"
      end

      poll_count += 1
      status_check_start = Time.current
      status_response = check_query_status(statement_handle)
      status_check_duration = Time.current - status_check_start

      status = status_response["statementStatusUrl"] ? "success" : status_response["status"]

      Rails.logger.info("[SnowflakeClient] 🔄 Poll ##{poll_count} (#{elapsed.round(1)}s elapsed): status=#{status} (check took #{status_check_duration.round(2)}s)")
      Rails.logger.debug("[SnowflakeClient] Query status response: #{status_response.inspect}")

      case status
      when "success"
        Rails.logger.info("[SnowflakeClient] ✅ Query completed after #{poll_count} polls (#{elapsed.round(2)}s total)")
        return status_response
      when "failed"
        error_msg = status_response["message"] || "Query execution failed"
        Rails.logger.error("[SnowflakeClient] ❌ Query failed after #{poll_count} polls: #{error_msg}")
        raise QueryExecutionError, error_msg
      when "running", "queued"
        Rails.logger.info("[SnowflakeClient] ⏳ Query still #{status}, sleeping #{poll_interval}s before next poll")
        sleep(poll_interval)
        poll_interval = [ poll_interval * 1.5, max_poll_interval ].min
      else
        Rails.logger.error("[SnowflakeClient] Unknown status. Full response: #{status_response.inspect}")
        raise QueryError, "Unknown query status: #{status.inspect}. Response: #{status_response.inspect}"
      end
    end
  end

  # Check query execution status
  def check_query_status(statement_handle)
    ensure_authenticated!

    response = http_client.get("#{api_endpoint}/#{statement_handle}") do |req|
      req.headers["Authorization"] = auth_header
    end

    handle_response_errors(response)
    JSON.parse(response.body)
  end

  # Fetch results from a completed query
  def fetch_query_results(statement_handle)
    ensure_authenticated!

    response = http_client.get("#{api_endpoint}/#{statement_handle}/result") do |req|
      req.headers["Authorization"] = auth_header
    end

    handle_response_errors(response)

    data = JSON.parse(response.body)
    parse_results(data)
  end

  # Parse Snowflake result format to array of hashes
  def parse_results(data)
    return [] unless data["data"]

    # Snowflake returns results as array of arrays with separate column metadata
    column_metadata = data["resultSetMetaData"]["rowType"]
    columns = column_metadata.map { |col| col["name"] }
    column_types = column_metadata.map { |col| col["type"] }
    rows = data["data"]

    Rails.logger.info("[SnowflakeClient] 📊 Parsing #{rows.size} rows with #{columns.size} columns")

    rows.map do |row|
      # Convert row array to hash with type conversions
      hash = {}
      columns.each_with_index do |col_name, idx|
        value = row[idx]
        col_type = column_types[idx]

        # Convert date integers (days since epoch) to ISO date strings
        if col_type == "date" && value.is_a?(String) && value.match?(/^-?\d+$/)
          # Snowflake returns dates as strings containing integers (days since 1970-01-01)
          days_since_epoch = value.to_i
          hash[col_name] = (Date.new(1970, 1, 1) + days_since_epoch).iso8601
        elsif col_type == "date" && value.is_a?(Integer)
          # Handle if returned as actual integer
          hash[col_name] = (Date.new(1970, 1, 1) + value).iso8601
        else
          hash[col_name] = value
        end
      end
      hash
    end
  end

  # Handle HTTP response errors
  def handle_response_errors(response)
    return if response.success?

    case response.status
    when 401
      # Clear token on auth failure to force re-authentication
      @jwt_token = nil
      @token_expires_at = nil
      raise AuthenticationError, "Authentication failed. Check credentials."
    when 403
      raise AuthenticationError, "Access forbidden. Check permissions."
    when 404
      raise QueryError, "Resource not found"
    when 429
      raise QueryError, "Rate limit exceeded"
    when 500..599
      raise ConnectionError, "Snowflake server error: #{response.status}"
    else
      error_body = JSON.parse(response.body) rescue { "message" => response.body }
      message = error_body["message"] || error_body["error"] || "HTTP #{response.status}"
      raise QueryError, message
    end
  end

  # HTTP client with retries
  def http_client
    @http_client ||= Faraday.new(url: base_url) do |f|
      f.request :retry, {
        max: 3,
        interval: 1,
        backoff_factor: 2,
        retry_statuses: [ 429, 500, 502, 503, 504 ]
      }
      f.adapter Faraday.default_adapter
      f.options.timeout = 60
      f.options.open_timeout = 10
    end
  end

  # Base URL for Snowflake account
  def base_url
    "https://#{account}.snowflakecomputing.com"
  end

  # SQL API endpoint
  def api_endpoint
    "/api/v2/statements"
  end

  # Bearer token auth header for JWT
  def auth_header
    "Bearer #{@jwt_token}"
  end
end
