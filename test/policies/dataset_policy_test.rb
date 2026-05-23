require "test_helper"

class DatasetPolicyTest < ActiveSupport::TestCase
  def setup
    @admin = users(:admin_user)
    @viewer = users(:viewer_user)
    @dataset = datasets(:sales_summary)
  end

  test "admin can do everything" do
    policy = DatasetPolicy.new(@admin, @dataset)

    assert policy.index?
    assert policy.show?
    assert policy.data?
    assert policy.create?
    assert policy.update?
    assert policy.destroy?
  end

  test "viewer can view data but not modify" do
    policy = DatasetPolicy.new(@viewer, @dataset)

    assert policy.index?
    assert policy.show?
    assert policy.data?
    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
  end
end
