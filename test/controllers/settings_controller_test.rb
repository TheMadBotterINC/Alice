require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin_user)
  end

  # Authorization tests
  test "unauthenticated users are redirected to sign in" do
    get settings_path
    assert_redirected_to sign_in_path
  end

  # Show tests
  test "authenticated user can view settings page" do
    sign_in_as @user

    get settings_path
    assert_response :success
    assert_select "h1", "Account Settings"
    assert_select "h2", "Profile Information"
    assert_select "h2", "Change Password"
  end

  # Profile update tests
  test "user can update their name" do
    sign_in_as @user

    patch settings_path, params: {
      user: {
        name: "Updated Name",
        email: @user.email
      }
    }

    assert_redirected_to settings_path
    assert_equal "Profile updated successfully.", flash[:success]

    @user.reload
    assert_equal "Updated Name", @user.name
  end

  test "user can update their email" do
    sign_in_as @user

    patch settings_path, params: {
      user: {
        name: @user.name,
        email: "newemail@test.example"
      }
    }

    assert_redirected_to settings_path
    assert_equal "Profile updated successfully.", flash[:success]

    @user.reload
    assert_equal "newemail@test.example", @user.email
  end

  test "user can update both name and email" do
    sign_in_as @user

    patch settings_path, params: {
      user: {
        name: "New Name",
        email: "new@test.example"
      }
    }

    assert_redirected_to settings_path

    @user.reload
    assert_equal "New Name", @user.name
    assert_equal "new@test.example", @user.email
  end

  test "profile update fails with invalid email" do
    sign_in_as @user

    patch settings_path, params: {
      user: {
        name: @user.name,
        email: "invalid_email"
      }
    }

    assert_response :unprocessable_entity

    @user.reload
    assert_not_equal "invalid_email", @user.email
  end

  test "profile update fails with blank name" do
    sign_in_as @user
    original_name = @user.name

    patch settings_path, params: {
      user: {
        name: "",
        email: @user.email
      }
    }

    assert_response :unprocessable_entity

    @user.reload
    assert_equal original_name, @user.name
  end

  test "profile update fails with duplicate email" do
    sign_in_as @user
    other_user = users(:other_user)

    patch settings_path, params: {
      user: {
        name: @user.name,
        email: other_user.email
      }
    }

    assert_response :unprocessable_entity

    @user.reload
    assert_not_equal other_user.email, @user.email
  end

  # Password change tests
  test "user can change their password" do
    sign_in_as @user
    original_password_digest = @user.password_digest

    patch settings_path, params: {
      user: {
        current_password: "password123",
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }

    assert_redirected_to settings_path
    assert_equal "Password changed successfully.", flash[:success]

    @user.reload
    assert_not_equal original_password_digest, @user.password_digest
    assert @user.authenticate("newpassword123")
  end

  test "password change fails with incorrect current password" do
    sign_in_as @user
    original_password_digest = @user.password_digest

    patch settings_path, params: {
      user: {
        current_password: "wrongpassword",
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }

    assert_response :unprocessable_entity

    @user.reload
    assert_equal original_password_digest, @user.password_digest
    assert @user.authenticate("password123") # Old password still works
  end

  test "password change fails with password too short" do
    sign_in_as @user
    original_password_digest = @user.password_digest

    patch settings_path, params: {
      user: {
        current_password: "password123",
        password: "short",
        password_confirmation: "short"
      }
    }

    assert_response :unprocessable_entity

    @user.reload
    assert_equal original_password_digest, @user.password_digest
  end

  test "password change fails with mismatched confirmation" do
    sign_in_as @user
    original_password_digest = @user.password_digest

    patch settings_path, params: {
      user: {
        current_password: "password123",
        password: "newpassword123",
        password_confirmation: "differentpassword"
      }
    }

    assert_response :unprocessable_entity

    @user.reload
    assert_equal original_password_digest, @user.password_digest
  end

  test "password change fails without current password" do
    sign_in_as @user
    original_password_digest = @user.password_digest

    patch settings_path, params: {
      user: {
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }

    assert_response :unprocessable_entity

    @user.reload
    assert_equal original_password_digest, @user.password_digest
  end

  test "user cannot change role through settings" do
    sign_in_as @user
    original_role = @user.role

    # Attempt to inject role change
    patch settings_path, params: {
      user: {
        name: @user.name,
        email: @user.email,
        role: "viewer"
      }
    }

    assert_redirected_to settings_path

    @user.reload
    assert_equal original_role, @user.role # Role unchanged
  end

  private

  def sign_in_as(user)
    post sign_in_path, params: { email: user.email, password: "password123" }
  end
end
