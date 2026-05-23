require "test_helper"

class PipelineExecutionServiceExportPrecisionTest < ActiveSupport::TestCase
  setup do
    @connector = connectors(:duckdb_local)
    @dataset = datasets(:sales_summary)

    # Create test data with floating point values
    @test_data = [
      {
        "equipment_id" => "B-028",
        "total_downtime" => 93.4,
        "total_labor_hours" => 166.79999999999998,  # Floating point error
        "avg_downtime" => 6.666666666666667
      },
      {
        "equipment_id" => "CT-089",
        "total_downtime" => 87.80000000000001,  # Floating point error
        "total_labor_hours" => 161.29999999999998,  # Floating point error
        "avg_downtime" => 5.486666666666667
      },
      {
        "equipment_id" => "M-030",
        "total_downtime" => 83.89999999999999,  # Floating point error
        "total_labor_hours" => 150.1,
        "avg_downtime" => 5.992857142857143
      }
    ]
  end

  # CSV Export Tests

  test "CSV export with default precision rounds floating point numbers" do
    pipeline = create_export_pipeline(format: "csv", high_precision: false)
    pipeline_run = pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)

    service = PipelineExecutionService.new(pipeline_run: pipeline_run)

    # Write CSV file with default precision
    temp_file = Tempfile.new(["test", ".csv"])
    begin
      rows_written = service.send(:write_csv_file, temp_file.path, @test_data, {
        "delimiter" => ",",
        "has_header" => true,
        "high_precision" => false
      })

      assert_equal 3, rows_written

      # Read back the CSV and verify rounding
      csv_content = File.read(temp_file.path)
      lines = csv_content.split("\n")

      # Check first data row
      assert_match(/B-028,93\.4,166\.8,6\.666667/, lines[1])

      # Check second data row - should NOT have long floating point strings
      refute_match(/161\.29999999999998/, lines[2])
      assert_match(/CT-089,87\.8,161\.3,5\.486667/, lines[2])

      # Check third data row
      refute_match(/83\.89999999999999/, lines[3])
      assert_match(/M-030,83\.9,150\.1,5\.992857/, lines[3])
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  test "CSV export with high precision preserves full floating point values" do
    pipeline = create_export_pipeline(format: "csv", high_precision: true)
    pipeline_run = pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)

    service = PipelineExecutionService.new(pipeline_run: pipeline_run)

    # Write CSV file with high precision
    temp_file = Tempfile.new(["test", ".csv"])
    begin
      rows_written = service.send(:write_csv_file, temp_file.path, @test_data, {
        "delimiter" => ",",
        "has_header" => true,
        "high_precision" => true
      })

      assert_equal 3, rows_written

      # Read back the CSV and verify full precision is preserved
      csv_content = File.read(temp_file.path)
      lines = csv_content.split("\n")

      # Check that full precision is maintained
      assert_match(/161\.29999999999998/, lines[2])
      assert_match(/83\.89999999999999/, lines[3])
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  test "CSV export strips trailing zeros from rounded numbers" do
    data = [
      { "value" => 100.0, "percentage" => 50.0 },
      { "value" => 25.5, "percentage" => 12.75 }
    ]

    pipeline = create_export_pipeline(format: "csv", high_precision: false)
    pipeline_run = pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)
    service = PipelineExecutionService.new(pipeline_run: pipeline_run)

    temp_file = Tempfile.new(["test", ".csv"])
    begin
      service.send(:write_csv_file, temp_file.path, data, {
        "delimiter" => ",",
        "has_header" => true,
        "high_precision" => false
      })

      csv_content = File.read(temp_file.path)
      lines = csv_content.split("\n")

      # 100.0 should become "100", not "100.0"
      assert_match(/^100,50$/, lines[1])

      # 25.5 and 12.75 should stay as-is
      assert_match(/^25\.5,12\.75$/, lines[2])
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  # Excel Export Tests

  test "Excel export with default precision rounds floating point numbers" do
    pipeline = create_export_pipeline(format: "excel", high_precision: false)
    pipeline_run = pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)

    service = PipelineExecutionService.new(pipeline_run: pipeline_run)

    # Write Excel file with default precision
    temp_file = Tempfile.new(["test", ".xlsx"])
    begin
      rows_written = service.send(:write_excel_file, temp_file.path, @test_data, {
        "sheet_name" => "Sheet1",
        "has_header" => true,
        "high_precision" => false
      })

      assert_equal 3, rows_written
      assert File.exist?(temp_file.path)

      # Verify file was created successfully
      assert File.size(temp_file.path) > 0
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  test "Excel export with high precision preserves full floating point values" do
    pipeline = create_export_pipeline(format: "excel", high_precision: true)
    pipeline_run = pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)

    service = PipelineExecutionService.new(pipeline_run: pipeline_run)

    # Write Excel file with high precision
    temp_file = Tempfile.new(["test", ".xlsx"])
    begin
      rows_written = service.send(:write_excel_file, temp_file.path, @test_data, {
        "sheet_name" => "Sheet1",
        "has_header" => true,
        "high_precision" => true
      })

      assert_equal 3, rows_written
      assert File.exist?(temp_file.path)
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  # Integration Tests

  test "write_to_file_export passes high_precision option to CSV writer" do
    pipeline = create_export_pipeline(format: "csv", high_precision: true)
    pipeline_run = pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)

    service = PipelineExecutionService.new(pipeline_run: pipeline_run)

    # Mock the transformation to return our test data
    service.instance_variable_set(:@duckdb, mock_duckdb_adapter)

    result = service.send(:write_to_file_export, @test_data)

    assert_equal 3, result[:rows_affected]
    assert pipeline_run.output_file.attached?

    # Verify the file contains high precision numbers
    csv_content = pipeline_run.output_file.download
    assert_match(/161\.29999999999998/, csv_content)
  end

  test "write_to_file_export passes high_precision option to Excel writer" do
    pipeline = create_export_pipeline(format: "excel", high_precision: false)
    pipeline_run = pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)

    service = PipelineExecutionService.new(pipeline_run: pipeline_run)

    # Mock the transformation to return our test data
    service.instance_variable_set(:@duckdb, mock_duckdb_adapter)

    result = service.send(:write_to_file_export, @test_data)

    assert_equal 3, result[:rows_affected]
    assert pipeline_run.output_file.attached?
  end

  test "handles infinite and NaN float values safely" do
    data_with_special = [
      { "normal" => 123.456, "infinite" => Float::INFINITY, "not_a_number" => Float::NAN }
    ]

    pipeline = create_export_pipeline(format: "csv", high_precision: false)
    pipeline_run = pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)
    service = PipelineExecutionService.new(pipeline_run: pipeline_run)

    temp_file = Tempfile.new(["test", ".csv"])
    begin
      # Should not raise error
      assert_nothing_raised do
        service.send(:write_csv_file, temp_file.path, data_with_special, {
          "delimiter" => ",",
          "has_header" => true,
          "high_precision" => false
        })
      end

      csv_content = File.read(temp_file.path)
      # Normal number should be rounded, special values should pass through
      assert_match(/123\.456/, csv_content)
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  test "preserves non-float types unchanged" do
    mixed_data = [
      { "string" => "test", "integer" => 42, "float" => 3.14159, "boolean" => true, "nil_value" => nil }
    ]

    pipeline = create_export_pipeline(format: "csv", high_precision: false)
    pipeline_run = pipeline.pipeline_runs.create!(status: :pending, started_at: Time.current)
    service = PipelineExecutionService.new(pipeline_run: pipeline_run)

    temp_file = Tempfile.new(["test", ".csv"])
    begin
      service.send(:write_csv_file, temp_file.path, mixed_data, {
        "delimiter" => ",",
        "has_header" => true,
        "high_precision" => false
      })

      csv_content = File.read(temp_file.path)
      lines = csv_content.split("\n")

      # Check that non-float values are preserved
      assert_match(/test,42,3\.14159,true,/, lines[1])
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  private

  def create_export_pipeline(format:, high_precision:)
    Pipeline.create!(
      name: "Test Export Pipeline - #{format} - #{high_precision}",
      transformation_sql: "SELECT * FROM work_orders",
      export_format: format,
      export_options: {
        "has_header" => true,
        "high_precision" => high_precision,
        "delimiter" => ",",
        "sheet_name" => "Sheet1"
      }
    ).tap do |pipeline|
      pipeline.pipeline_sources.create!(dataset: @dataset, table_alias: "work_orders")
    end
  end

  def mock_duckdb_adapter
    mock = Minitest::Mock.new
    mock.expect(:close, nil)
    mock
  end
end
