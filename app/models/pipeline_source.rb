class PipelineSource < ApplicationRecord
  belongs_to :pipeline
  belongs_to :connector, optional: true
  belongs_to :dataset, optional: true

  before_validation :set_default_table_alias, if: -> { table_alias.blank? && source.present? }

  validates :table_alias, presence: true, format: { with: /\A[a-zA-Z_][a-zA-Z0-9_]*\z/, message: "must be a valid SQL table name" }
  validate :must_have_either_connector_or_dataset
  validate :connector_cannot_be_destination_only
  validates :connector_id, uniqueness: { scope: :pipeline_id, message: "already added to this pipeline" }, if: -> { connector_id.present? }
  validates :dataset_id, uniqueness: { scope: :pipeline_id, message: "already added to this pipeline" }, if: -> { dataset_id.present? }

  # Return the source object (either connector or dataset)
  def source
    connector || dataset
  end

  # Return the type of source
  def source_type
    return "connector" if connector.present?
    return "dataset" if dataset.present?
    nil
  end

  # Return the source name for display
  def source_name
    source&.name
  end

  private

  def must_have_either_connector_or_dataset
    if connector_id.blank? && dataset_id.blank?
      errors.add(:base, "Must have either a connector or a dataset")
    elsif connector_id.present? && dataset_id.present?
      errors.add(:base, "Cannot have both a connector and a dataset")
    end
  end

  def connector_cannot_be_destination_only
    return if connector_id.blank?
    return unless connector

    if connector.destination_only?
      errors.add(:connector_id, "'#{connector.name}' is a #{connector.connector_type} connector and can only be used as a destination, not a source")
    end
  end

  def set_default_table_alias
    # Generate table alias from source name
    source_name = source.name.to_s.downcase.gsub(/[^a-z0-9_]/, "_").gsub(/__+/, "_").gsub(/^_|_$/, "")
    self.table_alias = source_name
  end
end
