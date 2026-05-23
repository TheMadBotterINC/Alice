class Dataset < ApplicationRecord
  # Associations
  belongs_to :connector

  # Pipeline associations
  has_many :pipeline_sources, dependent: :destroy
  has_many :source_pipelines, through: :pipeline_sources, source: :pipeline, class_name: "Pipeline"
  has_many :destination_pipelines, foreign_key: :destination_dataset_id, class_name: "Pipeline", dependent: :nullify

  # Status enum
  enum :status, {
    draft: 0,
    active: 1,
    archived: 2
  }, default: :draft

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :table_name, presence: true, format: { with: /\A[a-zA-Z_][a-zA-Z0-9_]*\z/, message: "must be a valid table name" }
  validates :schema_name, presence: true
  validates :connector_id, presence: true
  validates :table_name, uniqueness: { scope: [ :connector_id, :schema_name ], message: "already exists for this connector and schema" }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: :active) }
  scope :by_connector, ->(connector_id) { where(connector_id: connector_id) }
  scope :readable, -> { joins(:connector).where.not("connectors.connector_type LIKE ?", "file_%") }

  # Instance methods
  def column_names
    return [] unless schema.is_a?(Hash) && schema["columns"].is_a?(Array)
    schema["columns"].map { |col| col["name"] }
  end

  def column_types
    return {} unless schema.is_a?(Hash) && schema["columns"].is_a?(Array)
    schema["columns"].each_with_object({}) do |col, hash|
      hash[col["name"]] = col["type"]
    end
  end

  def status_variant
    case status.to_sym
    when :active then :success
    when :archived then :gray
    else :warning
    end
  end

  def fully_qualified_name
    "#{connector.name}.#{schema_name}.#{table_name}"
  end

  def source_table_path
    "#{connector.config['database']}.#{schema_name}.#{table_name}"
  end

  # Get all pipelines that use this dataset (either as source or destination)
  def related_pipelines
    Pipeline.where(id: source_pipelines.pluck(:id) + destination_pipelines.pluck(:id)).distinct
  end

  # Get pipelines that read FROM this dataset
  def upstream_pipelines
    source_pipelines
  end

  # Get pipelines that write TO this dataset
  def downstream_pipelines
    destination_pipelines
  end

  # Fetch paginated data from the dataset
  def fetch_data(page: 1, per_page: 100)
    offset = (page - 1) * per_page

    sql = <<~SQL
      SELECT *#{' '}
      FROM #{source_table_path}
      LIMIT #{per_page}#{' '}
      OFFSET #{offset}
    SQL

    connector.adapter.read_data(query: sql)
  rescue => e
    Rails.logger.error("Failed to fetch data for dataset #{id}: #{e.message}")
    Rails.logger.error("Error backtrace: #{e.backtrace.first(5).join("\n")}")
    # Fall back to empty array on error
    []
  end

  # Get total row count from the source table
  def total_rows
    # Use cached row_count if available and recent
    return row_count if row_count && updated_at > 1.hour.ago

    # For Snowflake, use approximate count from metadata which is much faster
    # and doesn't consume compute credits for large tables
    if connector.connector_type == "snowflake"
      sql = <<~SQL
        SELECT ROW_COUNT
        FROM #{connector.config['database']}.INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = '#{schema_name}'
          AND TABLE_NAME = '#{table_name}'
      SQL

      result = connector.adapter.read_data(query: sql)
      count = result.first&.dig("ROW_COUNT") || 0
    else
      # For other connectors, use exact count
      sql = "SELECT COUNT(*) as count FROM #{source_table_path}"
      result = connector.adapter.read_data(query: sql)
      count = result.first&.dig("COUNT") || result.first&.dig("count") || 0
    end

    # Update cached row count
    update_column(:row_count, count)
    count
  rescue => e
    Rails.logger.error("Failed to get row count for dataset #{id}: #{e.message}")
    Rails.logger.error("Error backtrace: #{e.backtrace.first(5).join("\n")}")
    row_count || 0
  end
end
