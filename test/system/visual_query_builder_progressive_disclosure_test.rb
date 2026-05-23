require "application_system_test_case"

class VisualQueryBuilderProgressiveDisclosureTest < ApplicationSystemTestCase
  setup do
    @user = users(:admin_user)
    sign_in_as @user
    
    @pipeline = pipelines(:visual_mode)
  end

  test "group by and order by sections are hidden initially" do
    visit visual_builder_pipeline_path(@pipeline)
    
    # Wait for page to load
    assert_selector "h1", text: "Visual Query Builder", wait: 5
    
    # Advanced sections should not be visible
    advanced_sections = all("[data-visual-query-builder-target='advancedSections']", visible: :all).first
    assert_not_nil advanced_sections, "Advanced sections element should exist"
    assert_equal "none", advanced_sections[:style].match(/display:\s*(\w+)/)[1], "Advanced sections should be hidden"
    
    # Banner should also be hidden initially
    banner = all("[data-visual-query-builder-target='advancedBanner']", visible: :all).first
    assert_not_nil banner, "Banner element should exist"
    assert_equal "none", banner[:style].match(/display:\s*(\w+)/)[1], "Banner should be hidden"
  end

  test "advanced sections appear after adding first column" do
    visit visual_builder_pipeline_path(@pipeline)
    
    # Wait for page to load
    assert_selector "h1", text: "Visual Query Builder", wait: 5
    
    # Verify initially hidden
    advanced_sections = all("[data-visual-query-builder-target='advancedSections']", visible: :all).first
    assert_equal "none", advanced_sections[:style].match(/display:\s*(\w+)/)[1]
    
    # Add a column by clicking
    within "[data-controller='column-selector']" do
      first("[data-column]").click
    end
    
    # Wait for animation
    sleep 0.6
    
    # Banner should now be visible
    banner = find("[data-visual-query-builder-target='advancedBanner']", visible: true)
    assert banner.visible?, "Banner should be visible after adding column"
    assert_text "Advanced Options Now Available!"
    
    # Advanced sections should be visible
    advanced_sections = find("[data-visual-query-builder-target='advancedSections']", visible: true)
    assert advanced_sections.visible?, "Advanced sections should be visible after adding column"
    
    # Should see Group By and Order By
    assert_text "Group By"
    assert_text "Sort (Order By)"
  end

  test "banner auto-dismisses after delay" do
    visit visual_builder_pipeline_path(@pipeline)
    
    # Wait for page load
    assert_selector "h1", text: "Visual Query Builder", wait: 5
    
    # Add a column
    within "[data-controller='column-selector']" do
      first("[data-column]").click
    end
    
    # Wait for banner to appear
    sleep 0.6
    assert_text "Advanced Options Now Available!"
    
    # Wait for banner to auto-dismiss (5 seconds + animation)
    sleep 5.5
    
    # Banner should be hidden now
    banner = all("[data-visual-query-builder-target='advancedBanner']", visible: :all).first
    assert_not banner.visible?, "Banner should auto-dismiss after 5 seconds"
    
    # But advanced sections should still be visible
    advanced_sections = find("[data-visual-query-builder-target='advancedSections']", visible: true)
    assert advanced_sections.visible?, "Advanced sections should remain visible after banner dismisses"
  end

  test "advanced sections remain visible even if columns are removed" do
    visit visual_builder_pipeline_path(@pipeline)
    
    # Wait for page load
    assert_selector "h1", text: "Visual Query Builder", wait: 5
    
    # Add a column
    within "[data-controller='column-selector']" do
      first("[data-column]").click
    end
    
    sleep 0.6
    
    # Verify sections are visible
    advanced_sections = find("[data-visual-query-builder-target='advancedSections']", visible: true)
    assert advanced_sections.visible?
    
    # Remove the column
    within "[data-visual-query-builder-target='columnsContainer']" do
      find("button", text: "✕").click
    end
    
    sleep 0.3
    
    # Advanced sections should still be visible (user intent preserved)
    advanced_sections = find("[data-visual-query-builder-target='advancedSections']", visible: true)
    assert advanced_sections.visible?, "Advanced sections should remain visible after removing all columns"
  end

  test "sections do not re-appear when adding multiple columns" do
    visit visual_builder_pipeline_path(@pipeline)
    
    # Wait for page load
    assert_selector "h1", text: "Visual Query Builder", wait: 5
    
    # Add first column
    columns = all("[data-column]")
    columns[0].click
    sleep 0.6
    
    # Note the banner text
    assert_text "Advanced Options Now Available!"
    
    # Add second column
    columns[1].click
    sleep 0.3
    
    # Banner should not re-appear or duplicate
    banner_count = all("[data-visual-query-builder-target='advancedBanner']", visible: true).count
    assert_equal 1, banner_count, "Should only have one banner visible"
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
