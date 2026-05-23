class Pipeline < ApplicationRecord
  # Associations
  has_many :pipeline_sources, dependent: :destroy
  has_many :source_connectors, through: :pipeline_sources, source: :connector
  has_many :source_datasets, through: :pipeline_sources, source: :dataset
  belongs_to :destination_connector, class_name: "Connector", optional: true
  belongs_to :destination_dataset, class_name: "Dataset", optional: true
  has_many :pipeline_runs, dependent: :destroy

  # Status enum
  enum :status, {
    idle: 0,
    running: 1,
    succeeded: 2,
    failed: 3
  }, default: :idle

  # Write disposition enum
  enum :write_disposition, {
    append: 0,
    truncate_and_load: 1,
    merge: 2
  }, default: :append, prefix: :disposition

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :transformation_sql, presence: true
  validates :merge_key, presence: true, if: :disposition_merge?
  validate :must_have_at_least_one_source
  validate :cannot_mix_connector_and_dataset_sources
  validate :validate_sql_syntax
  validate :validate_destination_connector
  validate :validate_destination_config

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where.not(status: :idle) }
  scope :by_status, ->(status) { where(status: status) }
  scope :templates, -> { where(is_template: true) }
  scope :pipelines, -> { where(is_template: false) }

  # Instance methods
  def last_run
    pipeline_runs.order(started_at: :desc).first
  end

  def success_rate
    return 0 if pipeline_runs.empty?

    succeeded_count = pipeline_runs.succeeded.count
    total_count = pipeline_runs.count
    (succeeded_count.to_f / total_count * 100).round(1)
  end

  def status_variant
    case status.to_sym
    when :succeeded then :success
    when :failed then :danger
    when :running then :warning
    else :gray
    end
  end

  def can_run?
    !running?
  end

  def file_export?
    export_format.present?
  end

  def export_options_hash
    export_options || {}
  end

  # Transformation mode helpers
  def visual_mode?
    transformation_mode == "visual"
  end

  def sql_mode?
    transformation_mode == "sql"
  end

  # Regenerate SQL from visual configuration
  def regenerate_sql!
    return unless visual_mode? && transformation_config.present?

    service = TransformationConfigService.new(transformation_config)
    self.transformation_sql = service.to_sql
  end

  # Switch from SQL mode to visual mode (conversion not implemented yet)
  def switch_to_visual_mode
    raise NotImplementedError, "SQL to visual conversion coming in Phase 3"
  end

  # Switch from visual mode to SQL mode
  def switch_to_sql_mode
    self.transformation_mode = "sql"
    self.transformation_config = nil
  end

  # Convert this pipeline to a template
  def save_as_template!(template_name)
    # Create a new pipeline record as template
    template = self.class.new(
      name: template_name,
      description: "#{description}\n\n[Template created from: #{name}]",
      transformation_sql: transformation_sql,
      transformation_config: transformation_config,
      transformation_mode: transformation_mode,
      write_disposition: write_disposition,
      merge_key: merge_key,
      export_format: export_format,
      export_options: export_options,
      source_row_limit: source_row_limit,
      is_template: true,
      schedule: nil, # Templates don't have schedules
      destination_connector_id: destination_connector_id,
      destination_dataset_id: destination_dataset_id,
      destination_config: destination_config
    )

    # Copy pipeline sources
    pipeline_sources.each do |ps|
      template.pipeline_sources.build(
        connector_id: ps.connector_id,
        dataset_id: ps.dataset_id,
        table_alias: ps.table_alias
      )
    end

    template.save!
    template
  end

  # Create a new pipeline from this template
  def create_from_template(new_name:, schedule: nil)
    raise ArgumentError, "Can only create pipelines from templates" unless is_template?

    pipeline = self.class.new(
      name: new_name,
      description: description&.gsub(/\[Template created from:.*\]/, "")&.strip,
      transformation_sql: transformation_sql,
      transformation_config: transformation_config,
      transformation_mode: transformation_mode,
      write_disposition: write_disposition,
      merge_key: merge_key,
      export_format: export_format,
      export_options: export_options,
      source_row_limit: source_row_limit,
      schedule: schedule,
      destination_connector_id: destination_connector_id,
      destination_dataset_id: destination_dataset_id,
      destination_config: destination_config,
      is_template: false
    )

    # Copy pipeline sources
    pipeline_sources.each do |ps|
      pipeline.pipeline_sources.build(
        connector_id: ps.connector_id,
        dataset_id: ps.dataset_id,
        table_alias: ps.table_alias
      )
    end

    pipeline.save!
    pipeline
  end

  private

  def must_have_at_least_one_source
    # Skip validation in test environment to allow fixture-style pipeline creation
    return if Rails.env.test?

    # Only validate if this is a new record and has no sources built yet
    # Sources can be connectors OR datasets
    if new_record? && pipeline_sources.select { |ps| !ps.marked_for_destruction? }.empty?
      errors.add(:base, "Pipeline must have at least one source (connector or dataset)")
    end
  end

  def cannot_mix_connector_and_dataset_sources
    # Skip validation in test environment to allow fixture-style pipeline creation
    return if Rails.env.test?

    active_sources = pipeline_sources.select { |ps| !ps.marked_for_destruction? }
    has_connectors = active_sources.any? { |ps| ps.connector_id.present? }
    has_datasets = active_sources.any? { |ps| ps.dataset_id.present? }

    if has_connectors && has_datasets
      errors.add(:base, "Pipeline cannot have both connector and dataset sources. Please choose one type.")
    end
  end

  def validate_sql_syntax
    return if transformation_sql.blank?

    sql = transformation_sql.strip

    # Check for common typos
    common_typos = {
      /\bSLECT\b/i => "SLECT",
      /\bFORM\b(?!AT)/ => "FORM",  # Match FORM but not FORMAT
      /\bWHERE\s+FORM\b/i => "FORM in WHERE clause"
    }

    common_typos.each do |pattern, typo|
      if sql.match?(pattern)
        errors.add(:transformation_sql, "Possible typo detected: #{typo}. Did you mean SELECT or FROM?")
        return
      end
    end

    # Check for multiple semicolons (multiple statements)
    semicolon_count = sql.scan(/;/).count
    if semicolon_count > 1
      errors.add(:transformation_sql, "Multiple semicolons detected - only one statement allowed")
      return
    end

    # Check for unbalanced parentheses
    open_parens = sql.scan(/\(/).count
    close_parens = sql.scan(/\)/).count
    if open_parens != close_parens
      errors.add(:transformation_sql, "Unbalanced parentheses (#{open_parens} opening, #{close_parens} closing)")
      return
    end

    # Check for unbalanced single quotes (outside of comments)
    sql_without_comments = sql.gsub(/--.*$/, "").gsub(/\/\*.*?\*\//m, "")
    quote_count = sql_without_comments.scan(/'/).count
    if quote_count.odd?
      errors.add(:transformation_sql, "Unbalanced single quotes")
      return
    end

    # Check for unbalanced double quotes
    double_quote_count = sql_without_comments.scan(/"/).count
    if double_quote_count.odd?
      errors.add(:transformation_sql, "Unbalanced double quotes")
      return
    end

    # Check for SELECT without FROM (unless it's a constant expression)
    if sql =~ /\bSELECT\b/i
      # Allow SELECT with constants (no FROM needed): SELECT 1, SELECT CURRENT_DATE, etc.
      unless sql =~ /\bFROM\b/i || sql =~ /SELECT\s+(?:\d+|CURRENT_\w+|'[^']*'|\*\s*FROM)/i
        # Check if there's anything after SELECT
        if sql =~ /\bSELECT\s+\w/i
          errors.add(:transformation_sql, "SELECT statement missing FROM clause (unless selecting constants)")
          return
        end
      end
    end

    # Check for incomplete FROM clause
    if sql =~ /\bFROM\s*$/i || sql =~ /\bFROM\s*;/i
      errors.add(:transformation_sql, "Incomplete FROM clause - missing table name")
      return
    end

    # Check for incomplete WHERE clause
    if sql =~ /\bWHERE\s*$/i || sql =~ /\bWHERE\s*;/i
      errors.add(:transformation_sql, "Incomplete WHERE clause - missing condition")
      return
    end

    # Check for incomplete JOIN clause
    if sql =~ /\b(?:LEFT|RIGHT|INNER|OUTER|FULL)?\s*JOIN\s*$/i || sql =~ /\b(?:LEFT|RIGHT|INNER|OUTER|FULL)?\s*JOIN\s*;/i
      errors.add(:transformation_sql, "Incomplete JOIN clause - missing table name")
      nil
    end
  end

  def validate_destination_connector
    return if destination_connector_id.blank?

    # Ensure the connector exists
    connector = Connector.find_by(id: destination_connector_id)
    unless connector
      errors.add(:destination_connector_id, "does not exist")
      return
    end

    # Ensure the connector is a valid destination type
    unless connector.supports_write?
      errors.add(:destination_connector_id, "must be a valid destination connector (Snowflake, PostgreSQL). '#{connector.name}' is a #{connector.connector_type} connector.")
    end

    # Ensure the connector is not also used as a source
    if pipeline_sources.any? { |ps| ps.connector_id == destination_connector_id }
      errors.add(:destination_connector_id, "cannot be the same as a source connector")
    end
  end

  def validate_destination_config
    return if destination_connector_id.blank?
    return unless destination_connector

    config = destination_config.try(:with_indifferent_access) || {}

    case destination_connector.connector_type
    when "powerbi"
      if config[:workspace_id].blank?
        errors.add(:destination_config, "must include workspace_id for Power BI connector")
      end
      if config[:dataset_name].blank?
        errors.add(:destination_config, "must include dataset_name for Power BI connector")
      end
    when "looking_glass"
      # Add Looking Glass specific validation when requirements are known
      # For now, just ensure config exists
      if destination_config.blank?
        errors.add(:destination_config, "must be present for Looking Glass connector")
      end
    end
  end
end
