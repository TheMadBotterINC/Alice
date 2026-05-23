module DatasetDisplayHelper
  # Analyze the dataset structure and suggest display format
  def analyze_dataset_structure(dataset, rows)
    return :empty if rows.blank?

    first_row = rows.first
    return :unknown unless first_row.is_a?(Hash)

    column_names = first_row.keys.map(&:to_s).map(&:upcase)

    # Detect time series data first (higher priority)
    # Time series tables often have VARIABLE columns too
    if has_timeseries_pattern?(column_names)
      return :timeseries
    end

    # Detect metadata/catalog tables
    if has_metadata_pattern?(column_names)
      return :metadata
    end

    # Default to tabular data
    :tabular
  end

  # Get primary/key columns to display prominently
  def primary_columns(dataset, rows)
    return [] if rows.blank?

    column_names = rows.first.keys.map(&:to_s)
    primary = []

    # Common key column patterns
    key_patterns = [
      /^(id|ID)$/,
      /name/i,
      /title/i,
      /description/i,
      /variable/i,
      /date/i,
      /time/i,
      /value/i,
      /amount/i
    ]

    column_names.each do |col|
      if key_patterns.any? { |pattern| col.match?(pattern) }
        primary << col
      end
    end

    # If no matches, take first 3-5 columns
    primary = column_names.first(5) if primary.empty?

    primary
  end

  # Get secondary/detail columns
  def secondary_columns(dataset, rows)
    return [] if rows.blank?

    all_columns = rows.first.keys.map(&:to_s)
    primary = primary_columns(dataset, rows)

    all_columns - primary
  end

  private

  def has_metadata_pattern?(column_names)
    # Must have both VARIABLE and VARIABLE_NAME to be considered metadata
    # or specific metadata-only indicators
    metadata_indicators = [
      "VARIABLE_NAME",
      "VARIABLE_DESCRIPTION",
      "ATTRIBUTE",
      "METADATA",
      "DEFINITION",
      "CATALOG"
    ]

    has_variable_name = column_names.include?("VARIABLE_NAME")
    has_other_metadata = (column_names & metadata_indicators).any?

    has_variable_name || has_other_metadata
  end

  def has_timeseries_pattern?(column_names)
    has_date = column_names.any? { |col| col.match?(/DATE|TIME|PERIOD|YEAR|MONTH/) }
    has_value = column_names.any? { |col| col.match?(/VALUE|AMOUNT|COUNT|RATE|LEVEL/) }

    has_date && has_value
  end
end
