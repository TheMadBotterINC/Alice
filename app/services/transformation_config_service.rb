# frozen_string_literal: true

# TransformationConfigService
#
# Converts visual query builder configuration (JSON) into DuckDB SQL statements.
# Supports SELECT, FROM, WHERE, GROUP BY, ORDER BY, and LIMIT clauses.
#
# Example configuration:
#   {
#     "version": "1.0",
#     "sources": [{ "type": "connector", "id": 123, "alias": "work_orders" }],
#     "columns": [
#       { "type": "source_column", "source": "work_orders", "name": "wo_number" },
#       { "type": "aggregation", "function": "COUNT", "column": {"source": "work_orders", "name": "id"}, "alias": "total" }
#     ],
#     "filters": [{ "column": {"source": "work_orders", "name": "status"}, "operator": "=", "value": "completed" }],
#     "groupBy": [{ "source": "work_orders", "name": "equipment_type" }],
#     "orderBy": [{ "column": "total", "direction": "DESC" }],
#     "limit": 100
#   }
class TransformationConfigService
  class ConfigurationError < StandardError; end

  REQUIRED_CONFIG_KEYS = %w[version sources columns].freeze
  SUPPORTED_AGGREGATIONS = %w[COUNT SUM AVG MIN MAX COUNT_DISTINCT].freeze
  SUPPORTED_OPERATORS = %w[= != > < >= <= LIKE IN BETWEEN IS_NULL IS_NOT_NULL].freeze
  SUPPORTED_SORT_DIRECTIONS = %w[ASC DESC].freeze

  def initialize(config)
    @config = config.is_a?(String) ? JSON.parse(config) : config
    @config = @config.with_indifferent_access if @config.respond_to?(:with_indifferent_access)
  end

  # Main method to convert configuration to SQL
  def to_sql
    validate_config!

    sql_parts = [
      build_select_clause,
      build_from_clause,
      build_where_clause,
      build_group_by_clause,
      build_order_by_clause,
      build_limit_clause
    ].compact

    sql_parts.join("\n")
  end

  # Validate that the configuration has required structure
  def validate_config!
    # Check for required top-level keys
    REQUIRED_CONFIG_KEYS.each do |key|
      raise ConfigurationError, "Missing required key: #{key}" unless @config.key?(key)
    end

    # Validate sources
    raise ConfigurationError, "At least one source is required" if @config[:sources].blank?
    @config[:sources].each { |source| validate_source!(source) }

    # Validate columns
    raise ConfigurationError, "At least one column is required" if @config[:columns].blank?
    @config[:columns].each { |column| validate_column!(column) }

    # Validate filters if present
    @config[:filters]&.each { |filter| validate_filter!(filter) }

    # Validate groupBy if present
    @config[:groupBy]&.each { |group_by_col| validate_group_by_column!(group_by_col) }

    # Validate orderBy if present
    @config[:orderBy]&.each { |order| validate_order_by!(order) }

    true
  end

  private

  def build_select_clause
    column_expressions = @config[:columns].map do |col|
      case col[:type]
      when "source_column"
        build_source_column_expression(col)
      when "aggregation", "aggregate"  # Support both formats
        build_aggregation_expression(col)
      else
        raise ConfigurationError, "Unknown column type: #{col[:type]}"
      end
    end

    "SELECT\n  #{column_expressions.join(",\n  ")}"
  end

  def build_source_column_expression(col)
    source = col[:source]
    name = col[:name]
    alias_name = col[:alias]

    qualified_column = "#{sanitize_identifier(source)}.#{sanitize_identifier(name)}"
    
    if alias_name.present?
      "#{qualified_column} AS #{sanitize_identifier(alias_name)}"
    else
      qualified_column
    end
  end

  def build_aggregation_expression(col)
    function = col[:function]&.upcase
    raise ConfigurationError, "Unsupported aggregation function: #{function}" unless SUPPORTED_AGGREGATIONS.include?(function)

    column_ref = col[:column]
    source = column_ref[:source]
    name = column_ref[:name]
    alias_name = col[:alias] || "#{function.downcase}_#{name}"

    qualified_column = "#{sanitize_identifier(source)}.#{sanitize_identifier(name)}"
    
    # Handle COUNT(DISTINCT ...) as special case
    if function == "COUNT_DISTINCT"
      "COUNT(DISTINCT #{qualified_column}) AS #{sanitize_identifier(alias_name)}"
    else
      "#{function}(#{qualified_column}) AS #{sanitize_identifier(alias_name)}"
    end
  end

  def build_from_clause
    # For now, assume single source. Multi-source with JOINs comes later
    source = @config[:sources].first
    table_alias = source[:alias]

    "FROM #{sanitize_identifier(table_alias)}"
  end

  def build_where_clause
    return nil if @config[:filters].blank?

    filter_expressions = @config[:filters].map do |filter|
      build_filter_expression(filter)
    end

    "WHERE #{filter_expressions.join("\n  AND ")}"
  end

  def build_filter_expression(filter)
    column_ref = filter[:column]
    source = column_ref[:source]
    name = column_ref[:name]
    operator = filter[:operator]&.upcase
    value = filter[:value]

    qualified_column = "#{sanitize_identifier(source)}.#{sanitize_identifier(name)}"

    case operator
    when "=", "!=", ">", "<", ">=", "<="
      "#{qualified_column} #{operator} #{format_value(value)}"
    when "LIKE"
      "#{qualified_column} LIKE #{format_value(value)}"
    when "IN"
      values = value.is_a?(Array) ? value : [value]
      formatted_values = values.map { |v| format_value(v) }.join(", ")
      "#{qualified_column} IN (#{formatted_values})"
    when "BETWEEN"
      # Expects value to be array with 2 elements [min, max]
      raise ConfigurationError, "BETWEEN requires array with 2 values" unless value.is_a?(Array) && value.size == 2
      "#{qualified_column} BETWEEN #{format_value(value[0])} AND #{format_value(value[1])}"
    when "IS_NULL"
      "#{qualified_column} IS NULL"
    when "IS_NOT_NULL"
      "#{qualified_column} IS NOT NULL"
    else
      raise ConfigurationError, "Unsupported operator: #{operator}"
    end
  end

  def build_group_by_clause
    return nil if @config[:groupBy].blank?

    group_by_columns = @config[:groupBy].map do |col|
      source = col[:source]
      name = col[:name]
      "#{sanitize_identifier(source)}.#{sanitize_identifier(name)}"
    end

    "GROUP BY #{group_by_columns.join(", ")}"
  end

  def build_order_by_clause
    return nil if @config[:orderBy].blank?

    order_expressions = @config[:orderBy].map do |order|
      column = order[:column]
      direction = order[:direction]&.upcase || "ASC"
      
      raise ConfigurationError, "Invalid sort direction: #{direction}" unless SUPPORTED_SORT_DIRECTIONS.include?(direction)

      "#{sanitize_identifier(column)} #{direction}"
    end

    "ORDER BY #{order_expressions.join(", ")}"
  end

  def build_limit_clause
    limit = @config[:limit]
    return nil if limit.blank?

    raise ConfigurationError, "LIMIT must be a positive integer" unless limit.is_a?(Integer) && limit > 0

    "LIMIT #{limit}"
  end

  # Sanitize identifiers to prevent SQL injection
  def sanitize_identifier(identifier)
    # Remove any characters that aren't alphanumeric or underscore
    sanitized = identifier.to_s.gsub(/[^a-zA-Z0-9_]/, "_")
    
    # Ensure it doesn't start with a number
    sanitized = "_#{sanitized}" if sanitized.match?(/^\d/)
    
    sanitized
  end

  # Format values for SQL (strings get quoted, numbers don't)
  def format_value(value)
    case value
    when String
      # Check if it's a SQL expression (starts with known functions or keywords)
      if value.match?(/^(CURRENT_DATE|CURRENT_TIMESTAMP|NOW\(\)|DATE\()/i)
        value
      else
        "'#{value.gsub("'", "''")}'"  # Escape single quotes
      end
    when Numeric
      value.to_s
    when true
      "TRUE"
    when false
      "FALSE"
    when nil
      "NULL"
    else
      "'#{value.to_s.gsub("'", "''")}'"
    end
  end

  # Validation helpers
  def validate_source!(source)
    raise ConfigurationError, "Source must have 'type'" unless source[:type].present?
    raise ConfigurationError, "Source must have 'alias'" unless source[:alias].present?
  end

  def validate_column!(column)
    raise ConfigurationError, "Column must have 'type'" unless column[:type].present?
    
    case column[:type]
    when "source_column"
      raise ConfigurationError, "Source column must have 'source' and 'name'" unless column[:source].present? && column[:name].present?
    when "aggregation", "aggregate"  # Support both formats
      raise ConfigurationError, "Aggregation must have 'function' and 'column'" unless column[:function].present? && column[:column].present?
    end
  end

  def validate_filter!(filter)
    raise ConfigurationError, "Filter must have 'column' and 'operator'" unless filter[:column].present? && filter[:operator].present?
    raise ConfigurationError, "Unsupported operator: #{filter[:operator]}" unless SUPPORTED_OPERATORS.include?(filter[:operator]&.upcase)
  end

  def validate_group_by_column!(col)
    raise ConfigurationError, "GROUP BY column must have 'source' and 'name'" unless col[:source].present? && col[:name].present?
  end

  def validate_order_by!(order)
    raise ConfigurationError, "ORDER BY must have 'column'" unless order[:column].present?
  end
end
