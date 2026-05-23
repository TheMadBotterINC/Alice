# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  # Only admins can view user lists
  def index?
    user.admin?
  end

  # Admins can view all users, users can view themselves
  def show?
    user.admin? || user == record
  end

  # Only admins can create new users
  def create?
    user.admin?
  end

  # Admins can update all users, users can update themselves
  def update?
    user.admin? || user == record
  end

  # Only admins can destroy users, but not themselves
  def destroy?
    user.admin? && user != record
  end
end
