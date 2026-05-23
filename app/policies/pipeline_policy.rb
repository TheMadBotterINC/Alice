# frozen_string_literal: true

class PipelinePolicy < ApplicationPolicy
  # All authenticated users can view pipelines
  def index?
    true
  end

  def show?
    true
  end

  # Only admins can create/update/destroy pipelines
  def create?
    user.admin?
  end

  def update?
    user.admin?
  end

  def destroy?
    user.admin?
  end

  # Only admins can run pipelines
  def run?
    user.admin?
  end

  # Only admins can save as template
  def save_as_template?
    user.admin?
  end

  def save_as_template_form?
    save_as_template?
  end

  # All authenticated users can view templates
  def templates?
    true
  end

  def new_from_template?
    true
  end

  # Only admins can create from template
  def create_from_template?
    user.admin?
  end

  # Visual builder actions
  def visual_builder?
    true
  end

  def new_visual_builder?
    user.admin?
  end

  def create_from_visual_builder?
    user.admin?
  end

  def update_from_visual_builder?
    user.admin?
  end
end
