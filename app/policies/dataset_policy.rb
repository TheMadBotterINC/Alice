# frozen_string_literal: true

class DatasetPolicy < ApplicationPolicy
  # All authenticated users can view datasets
  def index?
    true
  end

  def show?
    true
  end

  # All authenticated users can view dataset data
  def data?
    true
  end

  # Only admins can create/update/destroy datasets
  def create?
    user.admin?
  end

  def update?
    user.admin?
  end

  def destroy?
    user.admin?
  end
end
