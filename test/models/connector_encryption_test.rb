require "test_helper"

class ConnectorEncryptionTest < ActiveSupport::TestCase
  setup do
    @test_private_key = <<~KEY
      -----BEGIN PRIVATE KEY-----
      MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC7VJTUt9Us8cKj
      MzEfYyjiWA4R4/M2bS1+fWIcPm15j7eeU0Ua/yzVKAaSvLlgWgL9KBnO/qQ4i8W5
      -----END PRIVATE KEY-----
    KEY
  end

  test "encrypts Snowflake private_key when saving new connector" do
    connector = Connector.new(
      name: "Test Snowflake",
      connector_type: "snowflake",
      config: {
        "account" => "test_account",
        "username" => "test_user",
        "private_key" => @test_private_key,
        "database" => "TEST_DB",
        "warehouse" => "TEST_WH"
      }
    )

    connector.save!

    # Query raw database value
    result = Connector.connection.execute(
      "SELECT config->'private_key' as key FROM connectors WHERE id = #{connector.id}"
    )
    stored_key = result.first["key"].gsub(/"/, "")

    # Verify it's encrypted (has prefix)
    assert stored_key.start_with?("encrypted:"), "Private key should be encrypted in database"
    refute_equal @test_private_key, stored_key, "Stored value should not be plain text"
  end

  test "decrypts Snowflake private_key when loading connector" do
    connector = Connector.create!(
      name: "Test Snowflake 2",
      connector_type: "snowflake",
      config: {
        "account" => "test_account",
        "username" => "test_user",
        "private_key" => @test_private_key,
        "database" => "TEST_DB",
        "warehouse" => "TEST_WH"
      }
    )

    # Reload connector from database
    reloaded_connector = Connector.find(connector.id)

    # Verify decrypted value matches original
    assert_equal @test_private_key, reloaded_connector.config["private_key"]
  end

  test "does not re-encrypt already encrypted private_key" do
    connector = Connector.create!(
      name: "Test Snowflake 3",
      connector_type: "snowflake",
      config: {
        "account" => "test_account",
        "username" => "test_user",
        "private_key" => @test_private_key,
        "database" => "TEST_DB",
        "warehouse" => "TEST_WH"
      }
    )

    # Get the encrypted value
    first_encrypted = Connector.connection.execute(
      "SELECT config->'private_key' as key FROM connectors WHERE id = #{connector.id}"
    ).first["key"].gsub(/"/, "")

    # Update something else (not the private key)
    connector.update!(name: "Test Snowflake 3 Updated")

    # Get encrypted value again
    second_encrypted = Connector.connection.execute(
      "SELECT config->'private_key' as key FROM connectors WHERE id = #{connector.id}"
    ).first["key"].gsub(/"/, "")

    # Should be the same (not re-encrypted)
    assert_equal first_encrypted, second_encrypted
  end

  test "encrypts updated private_key" do
    connector = Connector.create!(
      name: "Test Snowflake 4",
      connector_type: "snowflake",
      config: {
        "account" => "test_account",
        "username" => "test_user",
        "private_key" => @test_private_key,
        "database" => "TEST_DB",
        "warehouse" => "TEST_WH"
      }
    )

    new_key = "-----BEGIN PRIVATE KEY-----\nNEW_KEY_DATA\n-----END PRIVATE KEY-----"

    # Update with new key
    connector.config["private_key"] = new_key
    connector.save!

    # Reload and verify new key is decrypted correctly
    reloaded = Connector.find(connector.id)
    assert_equal new_key, reloaded.config["private_key"]
  end

  test "does not encrypt private_key for non-Snowflake connectors" do
    connector = Connector.create!(
      name: "Test DuckDB",
      connector_type: "duckdb",
      config: {
        "database_path" => "/tmp/test.duckdb"
      }
    )

    # Verify config is stored as-is
    reloaded = Connector.find(connector.id)
    assert_equal "/tmp/test.duckdb", reloaded.config["database_path"]
  end

  test "handles decryption failure gracefully" do
    connector = Connector.create!(
      name: "Test Snowflake 5",
      connector_type: "snowflake",
      config: {
        "account" => "test_account",
        "username" => "test_user",
        "private_key" => @test_private_key,
        "database" => "TEST_DB",
        "warehouse" => "TEST_WH"
      }
    )

    # Manually corrupt the encrypted value in the database
    Connector.connection.execute(
      "UPDATE connectors SET config = jsonb_set(config, '{private_key}', '\"encrypted:CORRUPTED_DATA\"') WHERE id = #{connector.id}"
    )

    # Reload - should not crash, but mark as decryption failed
    reloaded = Connector.find(connector.id)
    assert_equal "[DECRYPTION_FAILED]", reloaded.config["private_key"]
  end

  test "decryption produces same plaintext for same key" do
    key = @test_private_key

    connector1 = Connector.create!(
      name: "Test Snowflake 6",
      connector_type: "snowflake",
      config: {
        "account" => "test_account",
        "username" => "test_user",
        "private_key" => key,
        "database" => "TEST_DB",
        "warehouse" => "TEST_WH"
      }
    )

    connector2 = Connector.create!(
      name: "Test Snowflake 7",
      connector_type: "snowflake",
      config: {
        "account" => "test_account2",
        "username" => "test_user2",
        "private_key" => key,
        "database" => "TEST_DB2",
        "warehouse" => "TEST_WH2"
      }
    )

    # Reload both to trigger after_find callback and decrypt
    connector1.reload
    connector2.reload

    # Both should decrypt to the same plaintext value
    assert_equal connector1.config["private_key"], connector2.config["private_key"]
    assert_equal key, connector1.config["private_key"]

    # But encrypted values should be different (non-deterministic encryption)
    encrypted1 = Connector.connection.execute(
      "SELECT config->'private_key' as key FROM connectors WHERE id = #{connector1.id}"
    ).first["key"].gsub(/"/, "")

    encrypted2 = Connector.connection.execute(
      "SELECT config->'private_key' as key FROM connectors WHERE id = #{connector2.id}"
    ).first["key"].gsub(/"/, "")

    refute_equal encrypted1, encrypted2, "Encrypted values should be different (non-deterministic encryption)"
  end

  test "encryption uses Rails secret_key_base" do
    connector = Connector.new(
      name: "Test Encryption Key",
      connector_type: "snowflake",
      config: {
        "account" => "test",
        "username" => "test",
        "private_key" => "test_key",
        "database" => "TEST",
        "warehouse" => "TEST"
      }
    )

    # Verify encryptor is created with derived key
    encryptor = connector.send(:encryptor)
    assert_instance_of ActiveSupport::MessageEncryptor, encryptor
  end
end
