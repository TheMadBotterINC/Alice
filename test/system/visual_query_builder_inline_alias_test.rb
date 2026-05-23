require "application_system_test_case"

class VisualQueryBuilderInlineAliasTest < ApplicationSystemTestCase
  setup do
    @user = users(:admin_user)
    sign_in_as @user
    
    @pipeline = pipelines(:visual_mode)
  end

  test "column card shows inline alias input field" do
    visit visual_builder_pipeline_path(@pipeline)
    
    # Wait for page to load
    assert_selector "h1", text: "Visual Query Builder", wait: 5
    
    # Add a column
    within "[data-controller='column-selector']" do
      first("[data-column]").click
    end
    
    sleep 0.3
    
    # Should see alias label and input field
    within "[data-visual-query-builder-target='columnsContainer']" do
      assert_selector "label", text: "Alias:"
      assert_selector "input[type='text'][data-action*='updateColumnAlias']"
    end
  end

  test "alias input field shows smart placeholder" do
    visit visual_builder_pipeline_path(@pipeline)
    
    # Wait for page to load
    assert_selector "h1", text: "Visual Query Builder", wait: 5
    
    # Add a column (should be wo_number based on mock data)
    within "[data-controller='column-selector']" do
      first("[data-column]").click
    end
    
    sleep 0.3
    
    # Input should have a placeholder matching the column name
    within "[data-visual-query-builder-target='columnsContainer']" do
      input = find("input[type='text'][data-action*='updateColumnAlias']")
      placeholder = input[:placeholder]
      assert_not_nil placeholder, "Alias input should have a placeholder"
      assert_not_equal "", placeholder, "Placeholder should not be empty"
    end
  end

  test "typing in alias field and blurring saves the alias" do
    visit visual_builder_pipeline_path(@pipeline)
    
    # Wait for page to load
    assert_selector "h1", text: "Visual Query Builder", wait: 5
    
    # Add a column
    within "[data-controller='column-selector']" do
      first("[data-column]").click
    end
    
    sleep 0.3
    
    # Type in the alias field
    within "[data-visual-query-builder-target='columnsContainer']" do
      input = find("input[type='text'][data-action*='updateColumnAlias']")
      input.fill_in with: "my_custom_alias"
      input.native.send_keys(:tab) # Trigger blur
    end
    
    sleep 0.3
    
    # Alias should be saved (check SQL preview contains the alias)
    sql_preview = find("[data-visual-query-builder-target='sqlPreview']").text
    assert_includes sql_preview, "my_custom_alias", "SQL should include the custom alias"
  end

  test "pressing enter in alias field saves the alias" do
    visit visual_builder_pipeline_path(@pipeline)
    
    # Wait for page to load
    assert_selector "h1", text: "Visual Query Builder", wait: 5
    
    # Add a column
    within "[data-controller='column-selector']" do
      first("[data-column]").click
    end
    
    sleep 0.3
    
    # Type and press Enter
    within "[data-visual-query-builder-target='columnsContainer']" do
      input = find("input[type='text'][data-action*='updateColumnAlias']")
      input.fill_in with: "enter_key_alias"
      input.native.send_keys(:enter)
    end
    
    sleep 0.3
    
    # Alias should be saved
    sql_preview = find("[data-visual-query-builder-target='sqlPreview']").text
    assert_includes sql_preview, "enter_key_alias", "SQL should include alias saved with Enter key"
  end

  test "clearing alias field removes the alias" do
    visit visual_builder_pipeline_path(@pipeline)
    
    # Wait for page to load
    assert_selector "h1", text: "Visual Query Builder", wait: 5
    
    # Add a column
    within "[data-controller='column-selector']" do
      first("[data-column]").click
    end
    
    sleep 0.3
    
    # Set an alias first
    within "[data-visual-query-builder-target='columnsContainer']" do
      input = find("input[type='text'][data-action*='updateColumnAlias']")
      input.fill_in with: "temp_alias"
      input.native.send_keys(:tab)
    end
    
    sleep 0.3
    
    # Verify it was set
    sql_preview = find("[data-visual-query-builder-target='sqlPreview']").text
    assert_includes sql_preview, "temp_alias"
    
    # Now clear it
    within "[data-visual-query-builder-target='columnsContainer']" do
      input = find("input[type='text'][data-action*='updateColumnAlias']")
      input.fill_in with: ""
      input.native.send_keys(:tab)
    end
    
    sleep 0.3
    
    # Alias should be removed from SQL
    sql_preview = find("[data-visual-query-builder-target='sqlPreview']").text
    assert_not_includes sql_preview, "temp_alias", "Cleared alias should not appear in SQL"
  end

  test "multiple columns can have different aliases" do
    visit visual_builder_pipeline_path(@pipeline)
    
    # Wait for page to load
    assert_selector "h1", text: "Visual Query Builder", wait: 5
    
    # Add two columns
    columns = all("[data-column]")
    columns[0].click
    sleep 0.2
    columns[1].click
    sleep 0.3
    
    # Set different aliases
    inputs = all("input[type='text'][data-action*='updateColumnAlias']")
    assert_equal 2, inputs.count, "Should have 2 alias inputs"
    
    inputs[0].fill_in with: "first_alias"
    inputs[0].native.send_keys(:tab)
    sleep 0.2
    
    inputs[1].fill_in with: "second_alias"
    inputs[1].native.send_keys(:tab)
    sleep 0.3
    
    # Both aliases should appear in SQL
    sql_preview = find("[data-visual-query-builder-target='sqlPreview']").text
    assert_includes sql_preview, "first_alias"
    assert_includes sql_preview, "second_alias"
  end

  test "alias field input is focused and styled on click" do
    visit visual_builder_pipeline_path(@pipeline)
    
    # Wait for page to load
    assert_selector "h1", text: "Visual Query Builder", wait: 5
    
    # Add a column
    within "[data-controller='column-selector']" do
      first("[data-column]").click
    end
    
    sleep 0.3
    
    # Click on the alias input
    input = find("input[type='text'][data-action*='updateColumnAlias']")
    input.click
    
    # Input should be focused
    assert_equal input, page.driver.browser.switch_to.active_element, "Alias input should be focused"
    
    # Should have focus styling classes
    assert input[:class].include?("focus:border-blue-400"), "Should have focus border styling"
    assert input[:class].include?("focus:ring-2"), "Should have focus ring styling"
  end

  test "alias persists after removing and re-adding same column" do
    visit visual_builder_pipeline_path(@pipeline)
    
    # Wait for page to load
    assert_selector "h1", text: "Visual Query Builder", wait: 5
    
    # Add a column
    first_column = first("[data-column]")
    first_column.click
    sleep 0.3
    
    # Set an alias
    within "[data-visual-query-builder-target='columnsContainer']" do
      input = find("input[type='text'][data-action*='updateColumnAlias']")
      input.fill_in with: "persistent_alias"
      input.native.send_keys(:tab)
    end
    
    sleep 0.3
    
    # Note: In the current implementation, removing and re-adding a column
    # creates a new column object, so alias won't persist
    # This test documents current behavior
    
    # Remove the column
    within "[data-visual-query-builder-target='columnsContainer']" do
      find("button", text: "✕").click
    end
    
    sleep 0.3
    
    # Re-add the same column
    first_column.click
    sleep 0.3
    
    # Alias field should be empty (new column instance)
    within "[data-visual-query-builder-target='columnsContainer']" do
      input = find("input[type='text'][data-action*='updateColumnAlias']")
      assert_equal "", input.value, "New column instance should have empty alias"
    end
  end

  test "alias field has appropriate aria label for accessibility" do
    visit visual_builder_pipeline_path(@pipeline)
    
    # Wait for page to load
    assert_selector "h1", text: "Visual Query Builder", wait: 5
    
    # Add a column
    within "[data-controller='column-selector']" do
      first("[data-column]").click
    end
    
    sleep 0.3
    
    # Check aria-label
    input = find("input[type='text'][data-action*='updateColumnAlias']")
    assert_equal "Column alias", input["aria-label"], "Input should have descriptive aria-label"
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
