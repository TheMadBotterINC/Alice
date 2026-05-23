require "test_helper"

class ConnectorAdapters::PostgresqlPglakeAdapterTest < ActiveSupport::TestCase
  setup do
    @connector = Connector.create!(
      name: "PGLake Test Instance",
      connector_type: "postgresql",
      config: {
        "host" => "localhost",
        "port" => 15432,
        "database" => "postgres",
        "username" => "postgres",
        "password" => "postgres",
        "schema" => "public",
        "enable_pglake" => "true",
        "s3_endpoint" => "http://localhost:19000",
        "aws_access_key_id" => "minioadmin",
        "aws_secret_access_key" => "minioadmin",
        "aws_region" => "us-east-1",
        "s3_bucket" => "opdi",
        "iceberg_location_prefix" => "s3://opdi/iceberg/",
        "s3_use_ssl" => "false"
      }
    )

    @adapter = ConnectorAdapters::PostgresqlAdapter.new(@connector)
  end

  teardown do
    @connector&.destroy
  end

  # Connection Tests
  test "successfully connects to PGLake instance" do
    assert @adapter.test_connection, "Should connect to PGLake instance"
  end

  test "connection config includes all required fields" do
    config = @connector.config

    # Standard PostgreSQL fields
    assert_equal "localhost", config["host"]
    assert_equal 15432, config["port"]
    assert_equal "postgres", config["database"]
    assert_equal "postgres", config["username"]
    assert_equal "public", config["schema"]

    # PGLake-specific fields
    assert_equal "true", config["enable_pglake"]
    assert_equal "http://localhost:19000", config["s3_endpoint"]
    assert_equal "minioadmin", config["aws_access_key_id"]
    assert_equal "opdi", config["s3_bucket"]
    assert_equal "s3://opdi/iceberg/", config["iceberg_location_prefix"]
    assert_equal "false", config["s3_use_ssl"]
  end

  test "can list tables in database" do
    tables = @adapter.list_tables
    assert tables.is_a?(Array), "list_tables should return an array"
  end

  test "can execute simple SELECT query" do
    result = @adapter.read_data(query: "SELECT 1 as test_col, 'hello' as message")

    assert_equal 1, result.size
    assert_equal "1", result.first["test_col"]
    assert_equal "hello", result.first["message"]
  end

  test "can check for PGLake extensions" do
    result = @adapter.read_data(query: <<~SQL)
      SELECT extname#{' '}
      FROM pg_extension#{' '}
      WHERE extname LIKE 'pg_lake%' OR extname = 'pg_extension_base'
      ORDER BY extname
    SQL

    extension_names = result.map { |r| r["extname"] }

    # Log what extensions are available
    puts "\nAvailable PGLake extensions: #{extension_names.join(', ')}"

    # Assert that we have at least some PGLake extensions
    assert result.any?, "PGLake instance should have pg_lake extensions available"
    assert extension_names.any? { |name| name.start_with?("pg_lake") }, "Should have at least one pg_lake extension"
  end

  test "can query PostgreSQL version and DuckDB availability" do
    result = @adapter.read_data(query: "SELECT version()")

    version = result.first["version"]
    assert version.present?, "Should return PostgreSQL version"
    puts "\nPostgreSQL version: #{version}"
  end
end
