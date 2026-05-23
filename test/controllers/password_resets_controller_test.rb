require "test_helper"

class PasswordResetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin_user)
  end

  test "should get new password reset form" do
    get new_password_reset_path
    assert_response :success
    assert_select "h2", "Reset your password"
    assert_select "input[type=email]"
  end

  test "should create password reset and send email" do
    assert_emails 1 do
      post password_resets_path, params: { email: @user.email }
    end

    @user.reload
    assert_not_nil @user.reset_password_token
    assert_not_nil @user.reset_password_sent_at

    assert_redirected_to sign_in_path
    assert_match /sent password reset instructions/i, flash[:notice]
  end

  test "should not reveal if email doesn't exist" do
    assert_no_emails do
      post password_resets_path, params: { email: "nonexistent@example.com" }
    end

    assert_redirected_to sign_in_path
    # Still shows success message (security best practice)
    assert_match /sent password reset instructions/i, flash[:notice]
  end

  test "should get edit password form with valid token" do
    @user.generate_password_reset_token

    get edit_password_reset_path(@user.reset_password_token)
    assert_response :success
    assert_select "h2", "Set new password"
    assert_select "input[type=password]", 2
  end

  test "should not get edit form with invalid token" do
    get edit_password_reset_path("invalid_token")

    assert_redirected_to sign_in_path
    assert_match /invalid or expired/i, flash[:alert]
  end

  test "should not get edit form with expired token" do
    @user.generate_password_reset_token
    @user.update_column(:reset_password_sent_at, 3.hours.ago)

    get edit_password_reset_path(@user.reset_password_token)

    assert_redirected_to new_password_reset_path
    assert_match /expired/i, flash[:alert]
  end

  test "should update password with valid token" do
    @user.generate_password_reset_token
    old_password_digest = @user.password_digest

    patch password_reset_path(@user.reset_password_token), params: {
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }

    @user.reload
    assert_not_equal old_password_digest, @user.password_digest
    assert_nil @user.reset_password_token
    assert_nil @user.reset_password_sent_at

    assert_redirected_to sign_in_path
    assert_match /password has been reset/i, flash[:notice]
  end

  test "should not update password with mismatched confirmation" do
    @user.generate_password_reset_token
    old_password_digest = @user.password_digest

    patch password_reset_path(@user.reset_password_token), params: {
      password: "newpassword123",
      password_confirmation: "differentpassword"
    }

    @user.reload
    assert_equal old_password_digest, @user.password_digest
    assert_response :unprocessable_entity
    # Flash message will contain password error
    assert flash.now[:alert].present?
  end

  test "should not update with blank password" do
    @user.generate_password_reset_token
    old_password_digest = @user.password_digest

    patch password_reset_path(@user.reset_password_token), params: {
      password: "",
      password_confirmation: ""
    }

    @user.reload
    assert_equal old_password_digest, @user.password_digest
    assert_response :unprocessable_entity
  end

  test "should not update password with expired token" do
    @user.generate_password_reset_token
    @user.update_column(:reset_password_sent_at, 3.hours.ago)
    old_password_digest = @user.password_digest

    patch password_reset_path(@user.reset_password_token), params: {
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }

    @user.reload
    assert_equal old_password_digest, @user.password_digest
    assert_redirected_to new_password_reset_path
  end

  test "should enforce minimum password length" do
    @user.generate_password_reset_token
    old_password_digest = @user.password_digest

    patch password_reset_path(@user.reset_password_token), params: {
      password: "short",
      password_confirmation: "short"
    }

    @user.reload
    assert_equal old_password_digest, @user.password_digest
    assert_response :unprocessable_entity
  end
end
