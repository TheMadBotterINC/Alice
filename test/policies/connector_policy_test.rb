require "test_helper"

class ConnectorPolicyTest < ActiveSupport::TestCase
  def setup
    @admin = users(:admin_user)
    @viewer = users(:viewer_user)
    @connector = connectors(:one)
  end

  test "admin can do everything" do
    policy = ConnectorPolicy.new(@admin, @connector)

    assert policy.index?
    assert policy.show?
    assert policy.create?
    assert policy.update?
    assert policy.destroy?
    assert policy.test_connection?
    assert policy.browse_tables?
    assert policy.available_tables?
    assert policy.table_schema?
  end

  test "viewer can view but not modify" do
    policy = ConnectorPolicy.new(@viewer, @connector)

    assert policy.index?
    assert policy.show?
    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
    assert_not policy.test_connection?
    assert policy.browse_tables?
    assert policy.available_tables?
    assert policy.table_schema?
  end
end
