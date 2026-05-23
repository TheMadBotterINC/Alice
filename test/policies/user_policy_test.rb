require "test_helper"

class UserPolicyTest < ActiveSupport::TestCase
  def setup
    @admin = users(:admin_user)
    @viewer = users(:viewer_user)
    @other_user = users(:other_user)
  end

  test "admin can do everything" do
    policy = UserPolicy.new(@admin, @other_user)

    assert policy.index?
    assert policy.show?
    assert policy.create?
    assert policy.update?
    assert policy.destroy?
  end

  test "admin cannot destroy themselves" do
    policy = UserPolicy.new(@admin, @admin)

    assert_not policy.destroy?
  end

  test "viewer cannot access user management" do
    policy = UserPolicy.new(@viewer, @other_user)

    assert_not policy.index?
    assert_not policy.show?
    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "viewer can view and update themselves" do
    policy = UserPolicy.new(@viewer, @viewer)

    assert_not policy.index?
    assert policy.show?
    assert_not policy.create?
    assert policy.update?
    assert_not policy.destroy?
  end

  test "user can view and update themselves" do
    policy = UserPolicy.new(@other_user, @other_user)

    assert policy.show?
    assert policy.update?
    assert_not policy.destroy?
  end
end
