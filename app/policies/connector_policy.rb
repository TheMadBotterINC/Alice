# frozen_string_literal: true

class ConnectorPolicy < ApplicationPolicy
  # All authenticated users can view connectors
  def index?
    true
  end

  def show?
    true
  end

  # Only admins can create/update/destroy connectors
  def create?
    user.admin?
  end

  def update?
    user.admin?
  end

  def destroy?
    user.admin?
  end

  # Only admins can test connections
  def test_connection?
    user.admin?
  end

  # All authenticated users can browse tables (needed for viewing data)
  def browse_tables?
    true
  end

  def available_tables?
    true
  end

  def table_schema?
    true
  end
end
