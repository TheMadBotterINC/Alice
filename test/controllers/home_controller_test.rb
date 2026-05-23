require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      name: "Test User",
      role: :viewer
    )
  end

  test "should redirect to sign in when not authenticated" do
    get root_url
    assert_redirected_to sign_in_url
  end

  test "should get index when authenticated" do
    sign_in_as @user
    get root_url
    assert_response :success
    assert_select "h1", /Welcome back/
  end

  test "should display dashboard statistics" do
    sign_in_as @user
    get root_url
    assert_response :success

    # Should display stat cards
    assert_select ".grid" do
      assert_select "p", text: /Total Pipelines/
      assert_select "p", text: /Active Connectors/
      assert_select "p", text: /Datasets/
      assert_select "p", text: /Last Run/
    end
  end

  test "should display recent pipeline runs section" do
    sign_in_as @user
    get root_url
    assert_response :success
    assert_select "h2", text: "Recent Pipeline Runs"
  end

  test "should display system health widget" do
    sign_in_as @user
    get root_url
    assert_response :success
    assert_select "h2", text: "System Health"
  end

  test "should display quick actions widget" do
    sign_in_as @user
    get root_url
    assert_response :success
    assert_select "h2", text: "Quick Actions"
  end

  test "should show empty state when no pipeline runs exist" do
    sign_in_as @user
    PipelineRun.delete_all

    get root_url
    assert_response :success
    assert_select "h3", text: "No pipeline runs yet"
  end

  private

  def sign_in_as(user)
    post sign_in_url, params: { email: user.email, password: "password123" }
  end
end
