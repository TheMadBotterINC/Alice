module ConnectorAdapters
  class BaseAdapter
    class AdapterError < StandardError; end
    class ConnectionError < AdapterError; end
    class QueryError < AdapterError; end

    attr_reader :connector

    def initialize(connector)
      @connector = connector
      validate_config!
    end

    # Read data from the connector
    # Returns: Array of hashes representing rows
    # @param query [String] Optional query/table name to read from
    # @return [Array<Hash>] Array of row hashes
    def read_data(query: nil)
      raise NotImplementedError, "Subclasses must implement read_data"
    end

    # Write data to the connector
    # @param table_name [String] Name of the table to write to
    # @param data [Array<Hash>] Array of row hashes to write
    # @param write_disposition [Symbol] :append, :truncate_and_load, or :merge
    # @return [Hash] Result with :rows_affected and other metadata
    def write_data(table_name:, data:, write_disposition: :append)
      raise NotImplementedError, "Subclasses must implement write_data"
    end

    # Test the connection
    # @return [Boolean] true if connection is successful
    def test_connection
      raise NotImplementedError, "Subclasses must implement test_connection"
    end

    # Get the schema for a table (column names and types)
    # @param table_name [String] Name of the table
    # @return [Array<Hash>] Array of column definitions with :name and :type
    def get_schema(table_name: nil)
      raise NotImplementedError, "Subclasses must implement get_schema"
    end

    protected

    def validate_config!
      raise ConnectionError, "Connector config is missing" unless connector.config.is_a?(Hash)
    end

    def log_info(message)
      Rails.logger.info("[#{self.class.name}] #{message}")
    end

    def log_error(message)
      Rails.logger.error("[#{self.class.name}] #{message}")
    end
  end
end
