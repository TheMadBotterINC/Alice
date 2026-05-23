require "application_system_test_case"

class VisualQueryBuilderCollapsibleJoinsTest < ApplicationSystemTestCase
  setup do
    @user = users(:admin_user)
    sign_in_as @user
    
    @pipeline = pipelines(:visual_mode)
  end

  test "joins section starts collapsed by default" do
    visit visual_builder_pipeline_path(@pipeline)
    
    # Wait for page to load
    assert_selector "h1", text: "Visual Query Builder", wait: 5
    
    # Joins section should exist
    assert_text "Table Joins"
    
    # Find the joins section with both controllers
    joins_section = find("[data-controller*='join-builder'][data-controller*='collapsible-section']")
    content = joins_section.all("[data-collapsible-section-target='content']", visible: :all).first
    
    assert_not_nil content, "Content target should exist"
    assert content[:class].include?("hidden"), "Joins content should be hidden initially"
    assert_equal "false", joins_section["aria-expanded"]
  end

  test "clicking joins header toggles section" do
    visit visual_builder_pipeline_path(@pipeline)
    
    # Wait for page load
    assert_selector "h1", text: "Visual Query Builder", wait: 5
    
    joins_section = find("[data-controller*='join-builder'][data-controller*='collapsible-section']")
    header = joins_section.find("[data-action*='collapsible-section#toggle']")
    content = joins_section.all("[data-collapsible-section-target='content']", visible: :all).first
    
    # Initially collapsed
    assert content[:class].include?("hidden")
    
    # Click to expand
    header.click
    
    # Wait for animation
    sleep 0.4
    
    # Should now be expanded
    assert_not content[:class].include?("hidden"), "Content should be visible after clicking header"
    assert_equal "true", joins_section["aria-expanded"]
    
    # Click again to collapse
    header.click
    
    # Wait for animation
    sleep 0.4
    
    # Should be collapsed again
    assert content[:class].include?("hidden"), "Content should be hidden after clicking header again"
  end

  test "adding a join auto-expands the section" do
    visit visual_builder_pipeline_path(@pipeline)
    
    # Wait for page load
    assert_selector "h1", text: "Visual Query Builder", wait: 5
    
    joins_section = find("[data-controller*='join-builder'][data-controller*='collapsible-section']")
    content = joins_section.all("[data-collapsible-section-target='content']", visible: :all).first
    
    # Initially collapsed
    assert content[:class].include?("hidden")
    
    # Click "Add Join" button
    within joins_section do
      click_button "Add Join"
    end
    
    # Wait for animation and join to be added
    sleep 0.5
    
    # Section should auto-expand
    assert_not content[:class].include?("hidden"), "Joins section should auto-expand when join is added"
    assert_equal "true", joins_section["aria-expanded"]
    
    # Join should be visible
    within content do
      assert_selector "span", text: "Join #1"
    end
  end

  test "toggle icon rotates when expanding and collapsing" do
    visit visual_builder_pipeline_path(@pipeline)
    
    # Wait for page load
    assert_selector "h1", text: "Visual Query Builder", wait: 5
    
    joins_section = find("[data-controller*='join-builder'][data-controller*='collapsible-section']")
    header = joins_section.find("[data-action*='collapsible-section#toggle']")
    icon = joins_section.find("[data-collapsible-section-target='toggleIcon']")
    
    # Initially should not be rotated (collapsed)
    initial_transform = icon[:style]
    assert initial_transform.include?("rotate(0deg)") || !initial_transform.include?("rotate"), "Icon should start at 0deg rotation"
    
    # Click to expand
    header.click
    sleep 0.4
    
    # Icon should be rotated
    expanded_transform = icon[:style]
    assert expanded_transform.include?("rotate(180deg)"), "Icon should rotate to 180deg when expanded"
    
    # Click to collapse
    header.click
    sleep 0.4
    
    # Icon should rotate back
    collapsed_transform = icon[:style]
    assert collapsed_transform.include?("rotate(0deg)"), "Icon should rotate back to 0deg when collapsed"
  end

  test "join count badge is visible when section is collapsed" do
    visit visual_builder_pipeline_path(@pipeline)
    
    # Wait for page load
    assert_selector "h1", text: "Visual Query Builder", wait: 5
    
    # Badge should be visible
    badge = find("#join-count")
    assert badge.visible?, "Join count badge should be visible"
    assert_equal "0", badge.text
    
    joins_section = find("[data-controller*='join-builder'][data-controller*='collapsible-section']")
    
    # Expand and add a join
    within joins_section do
      click_button "Add Join"
    end
    
    sleep 0.5
    
    # Badge should still be visible and updated (handled by visual-query-builder controller)
    badge = find("#join-count")
    assert badge.visible?, "Join count badge should remain visible after adding join"
  end

  test "expanded state persists across page reloads" do
    visit visual_builder_pipeline_path(@pipeline)
    
    # Wait for page load
    assert_selector "h1", text: "Visual Query Builder", wait: 5
    
    joins_section = find("[data-controller*='join-builder'][data-controller*='collapsible-section']")
    header = joins_section.find("[data-action*='collapsible-section#toggle']")
    content = joins_section.all("[data-collapsible-section-target='content']", visible: :all).first
    
    # Initially collapsed
    assert content[:class].include?("hidden")
    
    # Expand the section
    header.click
    sleep 0.4
    
    # Verify it's expanded
    assert_not content[:class].include?("hidden")
    
    # Reload the page
    visit visual_builder_pipeline_path(@pipeline)
    
    # Wait for page load
    assert_selector "h1", text: "Visual Query Builder", wait: 5
    
    # Section should still be expanded (from sessionStorage)
    joins_section = find("[data-controller*='join-builder'][data-controller*='collapsible-section']")
    content = joins_section.all("[data-collapsible-section-target='content']", visible: :all).first
    
    # Note: sessionStorage persists within the test session
    # This test verifies the state is restored
    assert_not content[:class].include?("hidden"), "Expanded state should persist across reloads"
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
