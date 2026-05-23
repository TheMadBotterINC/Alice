require "test_helper"

class ConnectorTest < ActiveSupport::TestCase
  def setup
    @connector = Connector.new(
      name: "Test Snowflake",
      connector_type: "snowflake",
      config: {
        "account" => "test_account",
        "username" => "test_user",
        "private_key" => "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC\n-----END PRIVATE KEY-----",
        "database" => "test_db",
        "warehouse" => "test_wh"
      }
    )
  end

  test "should be valid with valid attributes" do
    assert @connector.valid?
  end

  test "should require name" do
    @connector.name = nil
    assert_not @connector.valid?
    assert_includes @connector.errors[:name], "can't be blank"
  end

  test "should require unique name" do
    @connector.save!
    duplicate = @connector.dup
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "should require connector_type" do
    @connector.connector_type = nil
    assert_not @connector.valid?
    assert_includes @connector.errors[:connector_type], "can't be blank"
  end

  test "should only allow valid connector types" do
    @connector.connector_type = "invalid"
    assert_not @connector.valid?
    assert_includes @connector.errors[:connector_type], "is not included in the list"
  end

  test "should require config" do
    @connector.config = nil
    assert_not @connector.valid?
    assert_includes @connector.errors[:config], "can't be blank"
  end

  test "should validate snowflake config has required fields" do
    @connector.config = { "account" => "test" }
    assert_not @connector.valid?
    assert_includes @connector.errors[:config], "missing required fields for snowflake: username, private_key, database, warehouse"
  end

  test "should have pending status by default" do
    connector = Connector.new
    assert_equal "pending", connector.status
  end

  test "should support status enum" do
    @connector.save!

    @connector.connected!
    assert @connector.connected?
    assert_equal "connected", @connector.status

    @connector.error!
    assert @connector.error?

    @connector.disconnected!
    assert @connector.disconnected?
  end

  test "active scope should return only connected connectors" do
    connected = Connector.create!(
      name: "Connected",
      connector_type: "snowflake",
      config: { "account" => "a", "username" => "u", "private_key" => "-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----", "database" => "d", "warehouse" => "w" },
      status: :connected
    )

    error = Connector.create!(
      name: "Error",
      connector_type: "snowflake",
      config: { "account" => "a", "username" => "u", "private_key" => "-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----", "database" => "d", "warehouse" => "w" },
      status: :error
    )

    active_connectors = Connector.active
    assert_includes active_connectors, connected
    assert_not_includes active_connectors, error
  end

  test "recent scope should order by created_at desc" do
    PipelineRun.delete_all  # Clear pipeline runs first
    PipelineSource.delete_all  # Clear pipeline sources before pipelines
    Pipeline.delete_all  # Clear pipelines to avoid foreign key constraints
    Dataset.delete_all  # Clear datasets to avoid foreign key constraints
    Connector.delete_all  # Clear fixtures

    first = Connector.create!(
      name: "First",
      connector_type: "snowflake",
      config: { "account" => "a", "username" => "u", "private_key" => "-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----", "database" => "d", "warehouse" => "w" }
    )

    second = Connector.create!(
      name: "Second",
      connector_type: "snowflake",
      config: { "account" => "a", "username" => "u", "private_key" => "-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----", "database" => "d", "warehouse" => "w" }
    )

    recent = Connector.recent
    assert_equal second, recent.first
    assert_equal first, recent.last
  end

  test "test_connection should validate and test snowflake connection" do
    @connector.save!

    # Mock the adapter's test_connection method
    mock_adapter = Minitest::Mock.new
    mock_adapter.expect :test_connection, true

    @connector.stub :adapter, mock_adapter do
      result = @connector.test_connection
      assert result
    end

    @connector.reload
    assert @connector.connected?
    assert_not_nil @connector.last_checked_at
    mock_adapter.verify
  end

  test "status_variant should return correct variant" do
    @connector.status = :connected
    assert_equal :success, @connector.status_variant

    @connector.status = :error
    assert_equal :danger, @connector.status_variant

    @connector.status = :disconnected
    assert_equal :gray, @connector.status_variant

    @connector.status = :pending
    assert_equal :warning, @connector.status_variant
  end

end
