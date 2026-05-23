class Connector < ApplicationRecord
  # Associations
  has_many :pipeline_sources, dependent: :restrict_with_error
  has_many :pipelines_as_source, through: :pipeline_sources, source: :pipeline
  has_many :pipelines_as_destination, foreign_key: :destination_connector_id, class_name: "Pipeline", dependent: :restrict_with_error
  has_many :datasets, dependent: :restrict_with_error

  # Callbacks for encrypting/decrypting sensitive credentials
  before_save :encrypt_snowflake_private_key, if: -> { config_changed? && snowflake? }
  after_find :decrypt_snowflake_private_key, if: -> { snowflake? }
  after_initialize :decrypt_snowflake_private_key, if: -> { snowflake? && persisted? }

  # Status enum
  enum :status, {
    pending: 0,
    connected: 1,
    error: 2,
    disconnected: 3
  }, default: :pending

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :connector_type, presence: true, inclusion: { in: %w[snowflake duckdb file_csv file_excel file_upload postgresql] }
  validates :config, presence: true

  # Config validations per connector type
  validate :validate_connector_config

  # Scopes
  scope :active, -> { where(status: [ :connected ]) }
  scope :recent, -> { order(created_at: :desc) }

  # Test the connection using the adapter
  def test_connection
    return false unless valid?

    result = adapter.test_connection

    if result
      update(status: :connected, last_checked_at: Time.current)
    else
      update(status: :error, last_checked_at: Time.current)
    end

    result
  rescue StandardError => e
    update(status: :error, last_checked_at: Time.current)
    errors.add(:base, "Connection failed: #{e.message}")
    false
  end

  # Check if this is a Snowflake connector
  def snowflake?
    connector_type == "snowflake"
  end

  # Check if this is a file connector
  def file_connector?
    connector_type.to_s.start_with?("file_")
  end

  # Check if connector requires file upload at pipeline run time
  def upload_mode?
    file_connector? && config["mode"] == "upload"
  end

  # Check if this is a destination-only connector (write-only, cannot be used as source)
  def destination_only?
    false # No destination-only connectors in open-source version
  end

  # Check if this connector supports being a destination (can be written to)
  def supports_write?
    %w[snowflake postgresql].include?(connector_type)
  end

  # Get the appropriate adapter for this connector
  def adapter
    @adapter ||= case connector_type
    when "snowflake"
      ConnectorAdapters::SnowflakeAdapter.new(self)
    when "duckdb"
      ConnectorAdapters::DuckdbAdapter.new(self)
    when "file_csv", "file_excel", "file_upload"
      ConnectorAdapters::FileAdapter.new(self)
    when "postgresql"
      ConnectorAdapters::PostgresqlAdapter.new(self)
    else
      raise "Unknown connector type: #{connector_type}"
    end
  end

  # Get connection status badge variant
  def status_variant
    case status.to_sym
    when :connected then :success
    when :error then :danger
    when :disconnected then :gray
    else :warning
    end
  end

  private

  # Encrypt the Snowflake private_key before saving to database
  def encrypt_snowflake_private_key
    return unless config.is_a?(Hash) && config["private_key"].present?

    # Skip if already encrypted (marked with prefix)
    return if config["private_key"].start_with?("encrypted:")

    encrypted_value = encryptor.encrypt_and_sign(config["private_key"])
    config["private_key"] = "encrypted:#{encrypted_value}"
  end

  # Decrypt the Snowflake private_key after loading from database
  def decrypt_snowflake_private_key
    return unless config.is_a?(Hash) && config["private_key"].present?

    # Skip if not encrypted (no prefix)
    return unless config["private_key"].start_with?("encrypted:")

    encrypted_value = config["private_key"].sub(/^encrypted:/, "")
    config["private_key"] = encryptor.decrypt_and_verify(encrypted_value)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    # If decryption fails, log error but don't crash
    Rails.logger.error("Failed to decrypt private_key for connector #{id}")
    config["private_key"] = "[DECRYPTION_FAILED]"
  end

  # Get the encryptor instance
  def encryptor
    # Use Rails' secret_key_base to derive encryption key
    key = ActiveSupport::KeyGenerator.new(
      Rails.application.secret_key_base
    ).generate_key("connector_secrets", ActiveSupport::MessageEncryptor.key_len)

    ActiveSupport::MessageEncryptor.new(key)
  end

  def validate_connector_config
    return unless config.is_a?(Hash)

    required_keys = case connector_type
    when "snowflake"
      %w[account username private_key database warehouse]
    when "duckdb"
      %w[database_path]
    when "postgresql"
      %w[host database username password]
    when "file_csv", "file_excel"
      # File connectors: file_path mode requires path, upload mode requires nothing
      if config["mode"] == "upload"
        [] # Upload mode: file provided at pipeline run time
      else
        %w[file_path] # File path mode: requires server file path
      end
    when "file_upload"
      # Auto-detecting file upload connector: no path required
      [] # File provided at pipeline run time, format auto-detected
    else
      []
    end

    missing_keys = required_keys - config.keys

    if missing_keys.any?
      errors.add(:config, "missing required fields for #{connector_type}: #{missing_keys.join(', ')}")
    end

    # Validate private_key is not blank for Snowflake
    if connector_type == "snowflake" && config["private_key"].blank?
      errors.add(:config, "private_key cannot be blank for Snowflake connectors")
    end
  end
end
