# System Tests

System tests use Capybara with Selenium WebDriver to test JavaScript-heavy features in a real browser environment.

## Setup

System tests are already configured in `test/application_system_test_case.rb` to use headless Chrome.

### Requirements

- **Chrome browser** installed on your system
- **ChromeDriver** (automatically managed by Selenium Manager in modern setups)

### Installation Check

```bash
# Verify Chrome is installed
google-chrome --version  # Linux
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --version  # macOS

# If needed, install manually:
# macOS: brew install --cask google-chrome
# Linux: sudo apt-get install google-chrome-stable
```

## Running Tests

### Run All System Tests

```bash
bin/rails test:system
```

### Run Specific Test File

```bash
bin/rails test test/system/connector_wizard_test.rb
bin/rails test test/system/dashboard_charts_test.rb
```

### Run Single Test

```bash
bin/rails test test/system/connector_wizard_test.rb:20  # Line number
```

### Run with Visible Browser (for debugging)

Edit `test/application_system_test_case.rb` temporarily:

```ruby
driven_by :selenium, using: :chrome, screen_size: [1400, 1400]  # Remove :headless_chrome
```

Or use an environment variable:

```bash
HEADLESS=false bin/rails test:system
```

## Test Coverage

### `connector_wizard_test.rb` (19 tests)

Tests the multi-step connector creation wizard:

- ✅ Wizard navigation (next/back buttons)
- ✅ Connector type selection
- ✅ Dynamic field visibility for each connector type
- ✅ Required field validation
- ✅ HTML5 form validation (the bug we just fixed!)
- ✅ Progress indicator updates
- ✅ Review step summary
- ✅ Hidden fields don't have required attribute

**Key scenarios tested:**
- Snowflake, PostgreSQL, DuckDB, CSV, Excel, File Upload connectors
- Switching between connector types clears previous required attributes
- Form submission includes correct connector type

### `dashboard_charts_test.rb` (11 tests)

Tests Chart.js integration on the dashboard:

- ✅ Chart.js loads globally before Stimulus
- ✅ Multiple charts render simultaneously
- ✅ Charts render with and without data
- ✅ Placeholder messages when no data exists
- ✅ Chart lifecycle (connect/disconnect on navigation)
- ✅ Responsive behavior on window resize

**Key scenarios tested:**
- Execution timeline (bar chart)
- Success rate (doughnut chart)
- Top pipelines (horizontal bar)
- Data volume trend (line chart)

## Test Best Practices

### Waiting for JavaScript

Capybara automatically waits for elements, but you can be explicit:

```ruby
# Wait for element to appear
assert_selector "canvas[data-controller='chart']", wait: 5

# Wait for element to disappear
assert_no_selector ".loading-spinner", wait: 10
```

### JavaScript Execution

```ruby
# Execute JavaScript
page.execute_script("alert('Hello')")

# Get JavaScript values
chart_exists = page.evaluate_script("typeof Chart !== 'undefined'")
```

### Debugging Failed Tests

1. **Take screenshots on failure** (automatic in system tests):
   ```bash
   # Stored in: tmp/screenshots/failures_*.png
   ```

2. **Add `save_and_open_page`** during test development:
   ```ruby
   test "something" do
     visit root_path
     save_and_open_page  # Opens HTML in browser
   end
   ```

3. **Add `binding.break`** for interactive debugging:
   ```ruby
   test "something" do
     visit root_path
     binding.break  # Start debugger
     click_button "Submit"
   end
   ```

4. **Check console logs** (requires Chrome DevTools):
   ```ruby
   # After a failure, check:
   page.driver.browser.logs.get(:browser)
   ```

## Common Issues

### ChromeDriver Version Mismatch

```bash
# Update selenium-webdriver gem
bundle update selenium-webdriver
```

### Test Failing Locally But Passing in CI

- Window size differences: System tests use 1400x1400
- Timing issues: Add explicit waits
- Data isolation: Ensure fixtures don't conflict

### JavaScript Not Loading

```bash
# Precompile assets for test environment
RAILS_ENV=test bin/rails assets:precompile
```

## Performance

System tests are slower than unit tests because they:
- Boot a real browser
- Execute JavaScript
- Wait for page loads

**Optimization tips:**
- Run system tests separately: `bin/rails test:system`
- Use `parallelize(workers: 1)` in SystemTestCase if needed
- Keep system tests focused on critical user journeys

## CI/CD Integration

For GitHub Actions or similar:

```yaml
- name: Run system tests
  run: |
    bin/rails db:test:prepare
    bin/rails test:system
  env:
    RAILS_ENV: test
    HEADLESS: true
```

## Maintenance

As you add new JavaScript features:

1. **Add corresponding system tests** for:
   - User-facing interactions
   - JavaScript-driven UI changes
   - Form validation behavior
   - Dynamic content loading

2. **Keep tests focused**:
   - One feature per test
   - Clear test names
   - Minimal setup

3. **Update when UI changes**:
   - CSS selectors may break
   - Button text may change
   - Data attributes should be stable

## Examples

### Testing Modal Dialogs

```ruby
test "modal opens and closes" do
  visit root_path
  click_button "Open Modal"
  
  assert_selector "#modal", visible: true
  assert_text "Modal Content"
  
  click_button "Close"
  assert_no_selector "#modal", visible: true
end
```

### Testing AJAX Requests

```ruby
test "loads data via AJAX" do
  visit pipelines_path
  
  click_link "Load More"
  
  # Waits for new content
  assert_text "Additional Pipeline"
end
```

### Testing Stimulus Controllers

```ruby
test "stimulus controller responds to events" do
  visit new_connector_path
  
  # Trigger Stimulus action
  find("[data-action='click->wizard#next']").click
  
  # Assert controller updated the DOM
  assert_selector "[data-wizard-target='step2']", visible: true
end
```

---

**Total System Test Coverage: 30 tests**

These tests complement the existing 398 unit/integration tests, bringing total coverage to **428 tests** with comprehensive JavaScript testing.
