# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    true  # All authenticated users can view lists
  end

  def show?
    true  # All authenticated users can view individual records
  end

  def create?
    user.admin?  # Only admins can create
  end

  def new?
    create?
  end

  def update?
    user.admin?  # Only admins can update
  end

  def edit?
    update?
  end

  def destroy?
    user.admin?  # Only admins can destroy
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end
end
