require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      name: "Test User",
      role: :viewer
    )
  end

  test "should get sign in page" do
    get sign_in_url
    assert_response :success
    assert_select "h2", "Welcome back"
    assert_select "h1", "Alice"
  end

  test "should redirect to root if already authenticated" do
    sign_in_as @user
    get sign_in_url
    assert_redirected_to root_url
  end

  test "should sign in with valid credentials" do
    post sign_in_url, params: { email: @user.email, password: "password123" }
    assert_redirected_to root_url
    assert_equal @user.id, session[:user_id]
    assert_equal "Signed in successfully.", flash[:notice]
  end

  test "should not sign in with invalid email" do
    post sign_in_url, params: { email: "wrong@example.com", password: "password123" }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
    assert_equal "Invalid email or password.", flash[:alert]
  end

  test "should not sign in with invalid password" do
    post sign_in_url, params: { email: @user.email, password: "wrongpassword" }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
    assert_equal "Invalid email or password.", flash[:alert]
  end

  test "should sign out" do
    sign_in_as @user
    assert_equal @user.id, session[:user_id]

    delete sign_out_url
    assert_redirected_to sign_in_url
    assert_nil session[:user_id]
    assert_equal "Signed out successfully.", flash[:notice]
  end

  private

  def sign_in_as(user)
    post sign_in_url, params: { email: user.email, password: "password123" }
  end
end
