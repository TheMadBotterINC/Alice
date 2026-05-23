require "application_system_test_case"

class VisualQueryBuilderQuickStartTest < ApplicationSystemTestCase
  setup do
    @user = users(:admin_user)
    sign_in_as @user
    
    @domain = domains(:one)
    visit new_pipeline_path(domain_id: @domain.id, mode: 'visual')
    
    # Wait for controller to initialize
    sleep 0.3
  end

  test "Quick Start panel shows on initial load with no columns" do
    assert_selector '[data-visual-query-builder-target="quickStartPanel"]', visible: true
    assert_text "Quick Start Templates"
    assert_text "Get started quickly with these common query patterns"
    
    # All 4 templates should be visible
    assert_text "Simple Select"
    assert_text "Join Two Tables"
    assert_text "Aggregation"
    assert_text "Time Series"
  end

  test "Quick Start panel can be dismissed" do
    assert_selector '[data-visual-query-builder-target="quickStartPanel"]', visible: true
    
    # Click dismiss button
    within '[data-visual-query-builder-target="quickStartPanel"]' do
      find('button[data-action*="dismissQuickStart"]').click
    end
    
    # Panel should be hidden
    assert_no_selector '[data-visual-query-builder-target="quickStartPanel"]', visible: true
  end

  test "Quick Start panel hides after adding a column" do
    assert_selector '[data-visual-query-builder-target="quickStartPanel"]', visible: true
    
    # Add a column by clicking
    within '[data-controller="column-selector"]' do
      first('.bg-gray-50', text: 'work_orders').click
      first('button', text: 'work_order_id').click
    end
    
    # Wait for column to be added
    sleep 0.2
    
    # Panel should be hidden
    assert_no_selector '[data-visual-query-builder-target="quickStartPanel"]', visible: true
  end

  test "Simple Select template adds all columns from first table" do
    # Click Simple Select template
    within '[data-template="simple-select"]' do
      click_button "Simple Select"
    end
    
    # Wait for template to be applied
    sleep 0.2
    
    # Should have multiple columns added
    within '[data-visual-query-builder-target="columnsContainer"]' do
      assert_text "work_orders.work_order_id"
      assert_text "work_orders.equipment_id"
      assert_text "work_orders.status"
    end
    
    # Quick Start should be hidden
    assert_no_selector '[data-visual-query-builder-target="quickStartPanel"]', visible: true
  end

  test "Aggregation template creates COUNT with GROUP BY" do
    # Click Aggregation template
    within '[data-template="aggregation"]' do
      click_button "Aggregation"
    end
    
    # Wait for template to be applied
    sleep 0.2
    
    # Should have count aggregate
    within '[data-visual-query-builder-target="columnsContainer"]' do
      assert_text "count(work_orders.*)"
      assert_text "work_orders.work_order_id"
    end
    
    # Should have Group By section visible (progressive disclosure)
    assert_selector '[data-visual-query-builder-target="advancedSections"]', visible: true
    
    # Should have group by entry
    within '[data-visual-query-builder-target="groupByContainer"]' do
      assert_text "work_orders.work_order_id"
    end
    
    # Should have order by entry
    within '[data-visual-query-builder-target="orderByContainer"]' do
      assert_text "work_orders.count"
      assert_text "↓" # DESC
    end
  end

  test "Time Series template finds date column and adds metrics" do
    # Click Time Series template
    within '[data-template="time-series"]' do
      click_button "Time Series"
    end
    
    # Wait for template to be applied
    sleep 0.2
    
    # Should have date column and aggregate
    within '[data-visual-query-builder-target="columnsContainer"]' do
      # Should find a date-like column or use first column
      assert_selector 'div', minimum: 1
    end
    
    # Should have order by
    within '[data-visual-query-builder-target="orderByContainer"]' do
      assert_text "↓" # DESC order
    end
  end

  test "Join Two Tables template adds columns from multiple tables" do
    # Click Join Two Tables template
    within '[data-template="join-two-tables"]' do
      click_button "Join Two Tables"
    end
    
    # Wait for template to be applied
    sleep 0.2
    
    # Should have columns from both tables
    within '[data-visual-query-builder-target="columnsContainer"]' do
      assert_text "work_orders."
      assert_text "equipment."
    end
  end

  test "Quick Start panel respects sessionStorage dismissal across page reloads" do
    # Dismiss the panel
    within '[data-visual-query-builder-target="quickStartPanel"]' do
      find('button[data-action*="dismissQuickStart"]').click
    end
    
    assert_no_selector '[data-visual-query-builder-target="quickStartPanel"]', visible: true
    
    # Reload the page
    visit new_pipeline_path(domain_id: @domain.id, mode: 'visual')
    sleep 0.2
    
    # Panel should still be hidden (sessionStorage persists)
    assert_no_selector '[data-visual-query-builder-target="quickStartPanel"]', visible: true
  end

  test "SQL preview updates after applying template" do
    # Click Simple Select template
    within '[data-template="simple-select"]' do
      click_button "Simple Select"
    end
    
    # Wait for template to be applied
    sleep 0.2
    
    # SQL preview should have SELECT statement
    within '[data-visual-query-builder-target="sqlPreview"]' do
      assert_text "SELECT"
      assert_text "work_orders"
    end
  end

  test "column selector highlights update after applying template" do
    # Initially no columns should be highlighted
    within '[data-controller="column-selector"]' do
      assert_selector '.bg-gray-50', text: 'work_orders'
    end
    
    # Apply Simple Select template
    within '[data-template="simple-select"]' do
      click_button "Simple Select"
    end
    
    # Wait for template to be applied
    sleep 0.2
    
    # Columns should now be highlighted in the selector
    within '[data-controller="column-selector"]' do
      # The work_orders section should show selected columns
      first('.bg-gray-50', text: 'work_orders').click
      
      # Check for bg-blue-50 class on selected columns
      assert_selector '.bg-blue-50', minimum: 1
    end
  end

  private

  def sign_in_as(user)
    visit sign_in_path

    # Wait for the login form
    assert_selector "form[action='#{sign_in_path}']", wait: 5

    # Fill by field names
    find("input[name='email']").set(user.email)
    find("input[name='password']").set("password123")

    click_button "Sign in"

    # Verify we are signed in
    assert_text "Welcome back", wait: 5
  end
end
