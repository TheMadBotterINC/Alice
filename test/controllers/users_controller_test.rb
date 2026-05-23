require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @viewer = users(:viewer_user)
    @regular_user = users(:viewer_user)
  end

  # Authorization tests
  test "non-admin users cannot access user management" do
    sign_in_as @viewer

    get users_path
    assert_redirected_to root_path
    assert_equal "You are not authorized to perform this action.", flash[:alert]
  end

  test "viewers cannot access user management" do
    sign_in_as @viewer

    get users_path
    assert_redirected_to root_path
    assert_equal "You are not authorized to perform this action.", flash[:alert]
  end

  test "unauthenticated users are redirected to sign in" do
    get users_path
    assert_redirected_to sign_in_path
  end

  # Index tests
  test "admin can view users index" do
    sign_in_as @admin

    get users_path
    assert_response :success
    assert_select "h1", "User Management"
  end

  test "index shows all users" do
    sign_in_as @admin

    get users_path
    assert_response :success

    # Check that users are displayed
    assert_select "tbody tr", User.count
  end

  # New tests
  test "admin can access new user form" do
    sign_in_as @admin

    get new_user_path
    assert_response :success
    assert_select "h1", "Create New User"
    assert_select "form"
  end

  # Create tests
  test "admin can create user with password" do
    sign_in_as @admin

    assert_difference("User.count", 1) do
      post users_path, params: {
        user: {
          name: "New User",
          email: "newuser@example.com",
          role: "admin",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to users_path
    assert_equal "User created successfully.", flash[:success]

    new_user = User.find_by(email: "newuser@example.com")
    assert_not_nil new_user
    assert_equal "admin", new_user.role
  end

  test "admin can create user without password (auto-generates)" do
    sign_in_as @admin

    assert_difference("User.count", 1) do
      post users_path, params: {
        user: {
          name: "Auto Password User",
          email: "autopass@example.com",
          role: "viewer"
        }
      }
    end

    assert_redirected_to users_path
    assert_match(/Temporary password:/, flash[:success])

    new_user = User.find_by(email: "autopass@example.com")
    assert_not_nil new_user
    # Verify password was set (user can authenticate)
    assert new_user.authenticate(extract_temp_password_from_flash)
  end

  test "create fails with invalid data" do
    sign_in_as @admin

    assert_no_difference("User.count") do
      post users_path, params: {
        user: {
          name: "",
          email: "invalid",
          role: "admin"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create fails with duplicate email" do
    sign_in_as @admin

    assert_no_difference("User.count") do
      post users_path, params: {
        user: {
          name: "Duplicate",
          email: @viewer.email,
          role: "admin",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  # Edit tests
  test "admin can access edit user form" do
    sign_in_as @admin

    get edit_user_path(@viewer)
    assert_response :success
    assert_select "h1", "Edit User"
  end

  # Update tests
  test "admin can update user" do
    sign_in_as @admin

    patch user_path(@viewer), params: {
      user: {
        name: "Updated Name",
        role: "admin"
      }
    }

    assert_redirected_to users_path
    assert_equal "User updated successfully.", flash[:success]

    @viewer.reload
    assert_equal "Updated Name", @viewer.name
    assert_equal "admin", @viewer.role
  end

  test "admin can update user password" do
    sign_in_as @admin
    original_password_digest = @viewer.password_digest

    patch user_path(@viewer), params: {
      user: {
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }

    assert_redirected_to users_path

    @viewer.reload
    assert_not_equal original_password_digest, @viewer.password_digest
    assert @viewer.authenticate("newpassword123")
  end

  test "admin can update user without changing password" do
    sign_in_as @admin
    original_password_digest = @viewer.password_digest

    patch user_path(@viewer), params: {
      user: {
        name: "Name Change Only"
      }
    }

    assert_redirected_to users_path

    @viewer.reload
    assert_equal "Name Change Only", @viewer.name
    assert_equal original_password_digest, @viewer.password_digest
  end

  test "update fails with invalid data" do
    sign_in_as @admin

    patch user_path(@viewer), params: {
      user: {
        email: "invalid"
      }
    }

    assert_response :unprocessable_entity
  end

  # Destroy tests
  test "admin can delete user" do
    sign_in_as @admin
    user_to_delete = User.create!(
      name: "To Delete",
      email: "delete@example.com",
      password: "password123",
      role: "viewer"
    )

    assert_difference("User.count", -1) do
      delete user_path(user_to_delete)
    end

    assert_redirected_to users_path
    assert_equal "User deleted successfully.", flash[:success]
  end

  test "admin cannot delete their own account" do
    sign_in_as @admin

    assert_no_difference("User.count") do
      delete user_path(@admin)
    end

    assert_redirected_to users_path
    assert_equal "You cannot delete your own account.", flash[:error]
  end

  test "non-admin cannot delete users" do
    sign_in_as @viewer

    # Viewer tries to delete a different user (the admin)
    assert_no_difference("User.count") do
      delete user_path(@admin)
    end

    assert_redirected_to root_path
  end

  private

  def sign_in_as(user)
    post sign_in_path, params: { email: user.email, password: "password123" }
  end

  def extract_temp_password_from_flash
    # Extract the temporary password from flash message
    # Format: "User created successfully. Temporary password: <password>"
    match = flash[:success].match(/Temporary password: (.+)/)
    match[1] if match
  end
end
