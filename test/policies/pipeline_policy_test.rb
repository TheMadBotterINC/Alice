require "test_helper"

class PipelinePolicyTest < ActiveSupport::TestCase
  def setup
    @admin = users(:admin_user)
    @viewer = users(:viewer_user)
    @pipeline = pipelines(:one)
  end

  test "admin can do everything" do
    policy = PipelinePolicy.new(@admin, @pipeline)

    assert policy.index?
    assert policy.show?
    assert policy.create?
    assert policy.update?
    assert policy.destroy?
    assert policy.run?
    assert policy.save_as_template?
    assert policy.save_as_template_form?
    assert policy.templates?
    assert policy.new_from_template?
    assert policy.create_from_template?
  end

  test "viewer can view but not modify or run" do
    policy = PipelinePolicy.new(@viewer, @pipeline)

    assert policy.index?
    assert policy.show?
    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
    assert_not policy.run?
    assert_not policy.save_as_template?
    assert_not policy.save_as_template_form?
    assert policy.templates?
    assert policy.new_from_template?
    assert_not policy.create_from_template?
  end
end
