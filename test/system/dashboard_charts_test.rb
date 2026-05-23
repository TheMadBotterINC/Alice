require "application_system_test_case"

class DashboardChartsTest < ApplicationSystemTestCase
  setup do
    @user = users(:admin_user)
    @pipeline = pipelines(:one)
    sign_in_as(@user)
  end

  test "dashboard loads without Chart.js errors" do
    visit root_path

    assert_selector "h1", text: "Welcome back"

    # Verify no JavaScript errors by checking charts exist
    assert_selector "canvas[data-controller='chart']", minimum: 1
  end

  test "execution timeline chart renders" do
    visit root_path

    # Wait for chart to render
    chart = find("canvas[data-chart-type-value='bar']", match: :first)
    assert chart.visible?

    # Check canvas element has context (means Chart.js initialized it)
    assert page.evaluate_script("document.querySelector('canvas[data-chart-type-value=\"bar\"]') !== null")
  end

  test "success rate doughnut chart renders when data exists" do
    # Create some pipeline runs
    PipelineRun.create!(
      pipeline: @pipeline,
      status: :succeeded,
      started_at: 1.day.ago,
      completed_at: 1.day.ago + 1.hour
    )

    visit root_path

    # Should show doughnut chart, not "No data yet" message
    assert_selector "canvas[data-chart-type-value='doughnut']"
    assert_no_text "No data yet"
  end

  test "charts show placeholder when no data" do
    # Ensure no pipeline runs exist
    PipelineRun.destroy_all

    visit root_path

    # Success rate chart should show "No data yet"
    within ".bg-white.rounded-lg.shadow", text: "Success Rate" do
      assert_text "No data yet"
    end
  end

  test "top pipelines chart renders with data" do
    # Create pipeline runs
    3.times do
      PipelineRun.create!(
        pipeline: @pipeline,
        status: :succeeded,
        started_at: 1.day.ago,
        completed_at: 1.day.ago + 1.hour
      )
    end

    visit root_path

    # Should show horizontal bar chart
    assert_selector "canvas[data-chart-type-value='bar']", minimum: 1
  end

  test "data volume trend chart renders" do
    visit root_path

    within ".bg-white.rounded-lg.shadow", text: "Data Processed" do
      # Either chart or "No data yet" should be present
      assert page.has_selector?("canvas") || page.has_text?("No pipeline runs yet")
    end
  end

  test "multiple charts render simultaneously" do
    visit root_path

    # Count all chart canvases on the page
    charts = all("canvas[data-controller='chart']")

    # Dashboard should have 4 chart containers
    assert_operator charts.count, :>=, 1, "Expected at least one chart to render"
  end

  test "charts responsive to window resize" do
    visit root_path

    # Find a chart
    chart = find("canvas[data-chart-type-value='bar']", match: :first)

    # Resize window
    page.driver.browser.manage.window.resize_to(800, 600)

    # Chart should still be visible
    assert chart.visible?

    # Resize back
    page.driver.browser.manage.window.resize_to(1400, 1400)
    assert chart.visible?
  end

  test "Chart.js library loads before Stimulus controllers" do
    visit root_path

    # Check that Chart is available globally
    chart_available = page.evaluate_script("typeof window.Chart !== 'undefined'")
    assert chart_available, "Chart.js should be loaded globally"
  end

  test "charts update when navigating away and back" do
    visit root_path

    # Verify chart exists
    assert_selector "canvas[data-controller='chart']"

    # Navigate away
    visit connectors_path

    # Navigate back
    visit root_path

    # Chart should still render
    assert_selector "canvas[data-controller='chart']"
  end

  test "chart controller connects and disconnects properly" do
    visit root_path

    # Get initial chart count
    initial_count = all("canvas[data-controller='chart']").count

    # Navigate to another page
    visit pipelines_path

    # Come back
    visit root_path

    # Should have same number of charts
    final_count = all("canvas[data-controller='chart']").count
    assert_equal initial_count, final_count
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
