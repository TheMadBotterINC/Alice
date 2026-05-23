class PipelineRun < ApplicationRecord
  # Associations
  belongs_to :pipeline

  # ActiveStorage attachments
  has_one_attached :output_file  # For file exports (output)
  has_many_attached :source_files  # For uploaded source files (input)

  # Status enum
  enum :status, {
    pending: 0,
    running: 1,
    succeeded: 2,
    failed: 3
  }, default: :pending

  # Scopes
  scope :recent, -> { order(started_at: :desc) }
  scope :for_pipeline, ->(pipeline_id) { where(pipeline_id: pipeline_id) }

  # Callbacks
  before_create :set_started_at
  before_update :calculate_duration, if: :completed_at_changed?

  # Instance methods
  def complete_successfully!(row_count: 0)
    update!(
      status: :succeeded,
      completed_at: Time.current,
      row_count: row_count
    )
  end

  def complete_with_failure!(error_message)
    update!(
      status: :failed,
      completed_at: Time.current,
      error_message: error_message
    )
  end

  def mark_as_running!
    update!(status: :running)
  end

  def duration_in_seconds
    return nil unless completed_at && started_at
    (completed_at - started_at).to_i
  end

  def status_variant
    case status.to_sym
    when :succeeded then :success
    when :failed then :danger
    when :running then :warning
    else :gray
    end
  end

  private

  def set_started_at
    self.started_at ||= Time.current
  end

  def calculate_duration
    if completed_at && started_at
      self.duration = (completed_at - started_at).to_i
    end
  end
end
