require "application_system_test_case"

class ConnectorWizardTest < ApplicationSystemTestCase
  setup do
    @user = users(:admin_user)
    sign_in_as(@user)
  end

  test "wizard shows all connector type options" do
    visit new_connector_path

    assert_selector "h1", text: "Create New Connector"
    assert_selector "[data-connector-type='snowflake']"
    assert_selector "[data-connector-type='duckdb']"
    assert_selector "[data-connector-type='file']", count: 2  # CSV and Excel
    assert_selector "[data-connector-type='postgresql']"
    assert_selector "[data-connector-type='file_upload']"
  end

  test "next button is disabled until connector type is selected" do
    visit new_connector_path

    next_button = find("[data-connector-wizard-target='nextButton']")
    assert next_button.disabled?
    assert next_button[:class].include?("opacity-50")
  end

  test "selecting connector type enables next button" do
    visit new_connector_path

    # Click Snowflake card
    find("[data-connector-type='snowflake']").click

    next_button = find("[data-connector-wizard-target='nextButton']")
    assert_not next_button.disabled?
    assert_not next_button[:class].include?("opacity-50")
  end

  test "wizard navigates through steps correctly" do
    visit new_connector_path

    # Step 1: Select type
    assert_selector "[data-step-number='1'] .step-circle.bg-primary"
    find("[data-connector-type='snowflake']").click
    click_button "Next →"

    # Step 2: Configuration
    assert_selector "[data-step-number='2'] .step-circle.bg-primary"
    assert_selector "input[name='connector[name]']"
    assert_selector "#snowflake-fields", visible: true

    # Back button should be visible
    assert_selector "[data-connector-wizard-target='backButton']", visible: true

    # Go back
    click_button "← Back"
    assert_selector "[data-step-number='1'] .step-circle.bg-primary"
  end

  test "shows correct fields for Snowflake connector" do
    visit new_connector_path

    find("[data-connector-type='snowflake']").click
    click_button "Next →"

    assert_selector "#snowflake-fields", visible: true
    assert_selector "input[name='connector[config][account]']"
    assert_selector "input[name='connector[config][username]']"
    assert_selector "textarea[name='connector[config][private_key]']"
    assert_selector "input[name='connector[config][database]']"
    assert_selector "input[name='connector[config][warehouse]']"

    # Other connector fields should be hidden
    assert_selector "#duckdb-fields", visible: false
    assert_selector "#postgresql-fields", visible: false
  end

  test "shows correct fields for PostgreSQL connector" do
    visit new_connector_path

    find("[data-connector-type='postgresql']").click
    click_button "Next →"

    assert_selector "#postgresql-fields", visible: true
    assert_selector "input[name='connector[config][host]']"
    assert_selector "input[name='connector[config][port]']"
    assert_selector "input[name='connector[config][database]']"
    assert_selector "input[name='connector[config][username]']"
    assert_selector "input[name='connector[config][password]']"

    # Other connector fields should be hidden
    assert_selector "#snowflake-fields", visible: false
    assert_selector "#duckdb-fields", visible: false
  end

  test "shows correct fields for DuckDB connector" do
    visit new_connector_path

    find("[data-connector-type='duckdb']").click
    click_button "Next →"

    assert_selector "#duckdb-fields", visible: true
    assert_selector "input[name='connector[config][database_path]']"
    assert_selector "input[name='connector[config][read_only]']"
  end

  test "shows correct fields for CSV connector" do
    visit new_connector_path

    # Click CSV card (first file type)
    all("[data-connector-type='file']").first.click
    click_button "Next →"

    assert_selector "#csv-fields", visible: true
    assert_text "CSV / TSV File Configuration"
  end

  test "shows correct fields for Excel connector" do
    visit new_connector_path

    # Click Excel card (second file type)
    all("[data-connector-type='file']").last.click
    click_button "Next →"

    assert_selector "#excel-fields", visible: true
    assert_text "Excel File Configuration"
  end

  test "shows correct fields for file upload connector" do
    visit new_connector_path

    find("[data-connector-type='file_upload']").click
    click_button "Next →"

    assert_selector "#file_upload-fields", visible: true
    assert_text "File Upload Configuration"
  end

  test "required fields validation on step 2" do
    visit new_connector_path

    find("[data-connector-type='postgresql']").click
    click_button "Next →"

    # Try to go to next step without filling required fields
    click_button "Next →"

    # Should show error (using alert modal)
    assert_text "Required Fields Missing"
  end

  test "hidden connector fields do not have required attribute" do
    visit new_connector_path

    find("[data-connector-type='snowflake']").click
    click_button "Next →"

    # Fill minimum required Snowflake fields
    fill_in "connector[name]", with: "Test Snowflake"
    fill_in "connector[config][account]", with: "test"
    fill_in "connector[config][username]", with: "user"
    fill_in "connector[config][private_key]", with: "key"
    fill_in "connector[config][database]", with: "db"
    fill_in "connector[config][warehouse]", with: "wh"

    # Should be able to proceed to next step without HTML5 validation errors
    # This proves hidden PostgreSQL fields aren't blocking submission
    click_button "Next →"

    # Should reach step 3
    assert_selector "[data-step-number='3'] .step-circle.bg-primary"
  end

  test "switching connector types updates required fields" do
    visit new_connector_path

    # Select PostgreSQL first
    find("[data-connector-type='postgresql']").click
    click_button "Next →"

    # Go back and select DuckDB instead
    click_button "← Back"
    find("[data-connector-type='duckdb']").click
    click_button "Next →"

    # Fill DuckDB fields
    fill_in "connector[name]", with: "Test DuckDB"
    fill_in "connector[config][database_path]", with: "/tmp/test.duckdb"

    # Should be able to proceed without PostgreSQL validation errors
    # This proves switching types properly updates required fields
    click_button "Next →"

    # Should reach step 3
    assert_selector "[data-step-number='3'] .step-circle.bg-primary"
  end

  test "review step shows configuration summary" do
    visit new_connector_path

    # Go through wizard
    find("[data-connector-type='duckdb']").click
    click_button "Next →"

    fill_in "connector[name]", with: "Test DuckDB"
    fill_in "connector[config][database_path]", with: "/tmp/test.duckdb"

    click_button "Next →"

    # Step 3: Review
    assert_selector "[data-step-number='3'] .step-circle.bg-primary"
    assert_text "Review & Test Connection"
    assert_text "Test DuckDB"
    assert_text "DuckDB"
    assert_text "/tmp/test.duckdb"

    # Submit button should be visible
    assert_selector "input[value='Create Connector']", visible: true
  end

  test "progress indicators update correctly" do
    visit new_connector_path

    # Step 1 active
    step1 = find("[data-step-number='1'] .step-circle")
    assert step1[:class].include?("bg-primary")

    # Move to step 2
    find("[data-connector-type='snowflake']").click
    click_button "Next →"

    # Step 1 completed (green), Step 2 active
    step1 = find("[data-step-number='1'] .step-circle")
    assert step1[:class].include?("bg-green-500")

    step2 = find("[data-step-number='2'] .step-circle")
    assert step2[:class].include?("bg-primary")

    # Fill minimal fields and move to step 3
    fill_in "connector[name]", with: "Test"
    fill_in "connector[config][account]", with: "test"
    fill_in "connector[config][username]", with: "user"
    fill_in "connector[config][private_key]", with: "test-key"
    fill_in "connector[config][database]", with: "db"
    fill_in "connector[config][warehouse]", with: "wh"

    click_button "Next →"

    # Step 1 and 2 completed, Step 3 active
    step1 = find("[data-step-number='1'] .step-circle")
    assert step1[:class].include?("bg-green-500")

    step2 = find("[data-step-number='2'] .step-circle")
    assert step2[:class].include?("bg-green-500")

    step3 = find("[data-step-number='3'] .step-circle")
    assert step3[:class].include?("bg-primary")
  end

  test "form submission includes correct connector type" do
    visit new_connector_path

    find("[data-connector-type='postgresql']").click

    # Check hidden field is set
    type_field = find("input[name='connector[connector_type]']", visible: false)
    assert_equal "postgresql", type_field.value
  end

  test "CSV file mode selection works" do
    visit new_connector_path

    all("[data-connector-type='file']").first.click
    click_button "Next →"

    # CSV fields should be visible
    assert_selector "#csv-fields", visible: true

    # Default mode should be file_path (can verify via visible elements)
    # File path field should be visible in file_path mode
    assert_selector "input[name='connector[config][file_path]']", visible: true
  end

  test "back button hidden on first step" do
    visit new_connector_path

    assert_selector "[data-connector-wizard-target='backButton']", visible: false
  end

  test "submit button hidden until last step" do
    visit new_connector_path

    assert_selector "input[value='Create Connector']", visible: false

    # Navigate to last step
    find("[data-connector-type='file_upload']").click
    click_button "Next →"

    fill_in "connector[name]", with: "Test"
    click_button "Next →"

    # Now submit button should be visible
    assert_selector "input[value='Create Connector']", visible: true
    assert_selector "[data-connector-wizard-target='nextButton']", visible: false
  end

  private

  def sign_in_as(user)
    visit sign_in_path

    # Wait for the login form
    assert_selector "form[action='#{sign_in_path}']", wait: 5

    # Fill by field names to avoid label matching issues
    find("input[name='email']").set(user.email)
    find("input[name='password']").set("password123")

    click_button "Sign in"

    # Verify we are signed in (header visible on authenticated layout)
    assert_text "Welcome back", wait: 5
  end
end
