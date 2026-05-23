require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "should create valid user" do
    user = User.new(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      name: "Test User",
      role: :admin
    )
    assert user.valid?
    assert user.save
  end

  test "should require email" do
    user = User.new(name: "Test", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "should require unique email" do
    User.create!(email: "test@example.com", name: "Test", password: "password123")
    user = User.new(email: "test@example.com", name: "Test2", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  test "should require valid email format" do
    user = User.new(email: "invalid", name: "Test", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email], "is invalid"
  end

  test "should normalize email to lowercase" do
    user = User.create!(email: "TeSt@ExAmPlE.CoM", name: "Test", password: "password123")
    assert_equal "test@example.com", user.email
  end

  test "should require name" do
    user = User.new(email: "test@example.com", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "should require password with minimum length" do
    user = User.new(email: "test@example.com", name: "Test", password: "short")
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "should default to viewer role" do
    user = User.create!(email: "test@example.com", name: "Test", password: "password123")
    assert user.viewer?
  end

  test "should have role methods" do
    admin = User.create!(email: "test@example.com", name: "Test", password: "password123", role: :admin)
    assert admin.admin?
    assert_not admin.viewer?

    viewer = User.create!(email: "test2@example.com", name: "Test2", password: "password123", role: :viewer)
    assert viewer.viewer?
    assert_not viewer.admin?
  end
end
