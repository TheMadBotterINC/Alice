# Testing SQL Validation

This document explains how to run the SQL validation tests.

## Running System Tests

The SQL validation feature has comprehensive Capybara system tests that test the feature end-to-end in a real browser.

### Run All SQL Validation Tests

```bash
rails test:system test/system/pipeline_sql_validation_test.rb
```

### Run a Specific Test

```bash
rails test:system test/system/pipeline_sql_validation_test.rb:18
```

Replace `18` with the line number of the test you want to run.

### Run with Visible Browser (Non-Headless)

To see the tests running in a real browser window:

1. Edit `test/application_system_test_case.rb`
2. Change `using: :headless_chrome` to `using: :chrome`
3. Run the tests as normal

## Test Coverage

The system tests cover:

### Invalid SQL Scenarios

- ✅ Missing FROM clause
- ✅ Unbalanced parentheses
- ✅ Unbalanced single quotes
- ✅ Incomplete FROM clause (`SELECT * FROM`)
- ✅ Incomplete WHERE clause (`SELECT * FROM orders WHERE`)
- ✅ Incomplete JOIN clause (`SELECT * FROM orders o LEFT JOIN`)
- ✅ Common SQL typos (SLECT, FORM, WEHRE, etc.)
- ✅ Multiple semicolons (multiple statements)

### Valid SQL Scenarios

- ✅ Basic SELECT queries
- ✅ SELECT with WHERE, JOIN, GROUP BY, ORDER BY
- ✅ WITH (CTE) queries
- ✅ Complex JOIN queries
- ✅ SELECT with constants (SELECT 1, SELECT CURRENT_DATE)

### User Experience

- ✅ Error messages display correctly
- ✅ SQL field gets red border on error
- ✅ Page scrolls to SQL field on error
- ✅ SQL field receives focus on error
- ✅ Errors clear when SQL is fixed
- ✅ Form submission is prevented when SQL is invalid
- ✅ Pipeline is created when SQL is valid

### Both Create and Edit Pages

- ✅ Validation works on new pipeline page
- ✅ Validation works on edit pipeline page

## Prerequisites

### Database Setup

Make sure your test database is set up:

```bash
rails db:test:prepare
```

### Chrome/Chromium

System tests require Chrome or Chromium to be installed:

```bash
# Ubuntu/Debian
sudo apt-get install chromium-browser

# Or download Chrome
# https://www.google.com/chrome/
```

### Chromedriver

The `selenium-webdriver` gem should handle chromedriver automatically, but if you have issues:

```bash
# Ubuntu/Debian
sudo apt-get install chromium-chromedriver
```

## Debugging Tests

### View Screenshots on Failure

When a system test fails, Capybara automatically saves a screenshot. Look for:

```
tmp/screenshots/failures_*.png
```

### Add Debug Breakpoints

Add `debugger` anywhere in a test to pause execution:

```ruby
test "should validate SQL" do
  fill_in "SQL Query", with: "invalid SQL"
  debugger  # Execution pauses here
  click_button "Create Pipeline"
end
```

### View Browser State

Use `save_and_open_page` to save the current HTML and open it in a browser:

```ruby
test "should validate SQL" do
  fill_in "SQL Query", with: "invalid SQL"
  click_button "Create Pipeline"
  save_and_open_page  # Opens browser with current page state
end
```

### Verbose Output

Run with verbose output to see detailed logs:

```bash
rails test:system test/system/pipeline_sql_validation_test.rb --verbose
```

## Running All Tests

To run all system tests (not just SQL validation):

```bash
rails test:system
```

To run all tests (unit, integration, system):

```bash
rails test
```

## Continuous Integration

These tests are suitable for CI/CD pipelines. Example GitHub Actions configuration:

```yaml
- name: Run system tests
  env:
    RAILS_ENV: test
  run: |
    bundle exec rails db:test:prepare
    bundle exec rails test:system
```

## Test Performance

System tests are slower than unit tests because they:
- Start a real browser
- Load JavaScript
- Interact with the page like a real user

Expected runtime:
- Single test: ~2-5 seconds
- Full suite: ~30-60 seconds

## Parallel Testing

Rails supports parallel system tests:

```bash
# Run with 4 parallel workers
rails test:system PARALLEL_WORKERS=4
```

Note: System tests may be less reliable in parallel due to browser/driver contention.

## Common Issues

### Chrome/Chromedriver Version Mismatch

If you see errors about incompatible Chrome/Chromedriver versions:

```bash
# Update chromedriver
gem update selenium-webdriver
```

### Port Already in Use

If tests fail with "port already in use":

```bash
# Kill any lingering Rails test servers
pkill -f 'rails.*server'
```

### Flaky Tests

If tests are flaky (sometimes pass, sometimes fail):

1. Add explicit waits:
   ```ruby
   assert_text "Error message", wait: 5  # Wait up to 5 seconds
   ```

2. Use `have_selector` with wait:
   ```ruby
   assert_selector ".error", text: "Error message"
   ```

3. Check for JavaScript timing issues in the controllers

## Manual Testing Checklist

Before deploying, manually test:

- [ ] Invalid SQL shows error
- [ ] Valid SQL submits successfully
- [ ] Error styling (red border) appears
- [ ] Error message is clear and helpful
- [ ] Page scrolls to SQL field
- [ ] Error clears when SQL is fixed
- [ ] Works on both new and edit pages
- [ ] Works with different SQL types (SELECT, WITH, etc.)
- [ ] Mobile/responsive behavior

## Adding New Tests

When adding new validation rules, add tests for:

1. **Happy path**: Valid SQL that should pass
2. **Error path**: Invalid SQL that should fail with specific error
3. **Edge cases**: Boundary conditions, empty strings, etc.
4. **User experience**: Error display, focus, scrolling

Example:

```ruby
test "should validate new rule" do
  fill_in "Name", with: "Test Pipeline"
  check "pipeline_source_connector_ids_#{@connector.id}"
  fill_in "SQL Query", with: "SQL that triggers new rule"
  
  click_button "Create Pipeline"
  
  assert_text "Expected error message"
  assert_no_difference "Pipeline.count"
end
```
