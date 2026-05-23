class DatasetsController < ApplicationController
  before_action :set_dataset, only: [ :show, :edit, :update, :destroy, :data ]

  def index
    @datasets = Dataset.includes(:connector).recent
    authorize Dataset
  end

  def show
    authorize @dataset
    # Fetch sample data preview (first 10 rows) with caching
    cache_key = "dataset_#{@dataset.id}_sample_preview"
    @sample_data = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      begin
        @dataset.fetch_data(page: 1, per_page: 10)
      rescue => e
        Rails.logger.error("Failed to fetch sample data for dataset #{@dataset.id}: #{e.message}")
        [] # Return empty array on error
      end
    end
  end

  def new
    @dataset = Dataset.new
    authorize @dataset
    @connectors = Connector.all.order(:name)

    # Pre-populate from browse_tables if coming from there
    if params[:connector_id] && params[:schema_name] && params[:table_name]
      begin
        connector = Connector.find(params[:connector_id])
        @dataset.connector_id = params[:connector_id]
        @dataset.schema_name = params[:schema_name]
        @dataset.table_name = params[:table_name]
        @dataset.name = "#{params[:schema_name]}.#{params[:table_name]}".gsub("_", " ").titleize

        # Fetch the table schema
        @table_schema = connector.adapter.get_table_schema(
          schema_name: params[:schema_name],
          table_name: params[:table_name]
        )
        @dataset.schema = { columns: @table_schema[:columns] }
      rescue ActiveRecord::RecordNotFound
        flash.now[:alert] = "Connector not found. Please select a valid connector."
      rescue StandardError => e
        Rails.logger.error("Failed to fetch table schema: #{e.message}")
        Rails.logger.error(e.backtrace.first(5).join("\n"))
        flash.now[:alert] = "Could not connect to data source or fetch table schema. Please verify the connection and try again."
      end
    end
  end

  def create
    Rails.logger.info "\n" + "=" * 80
    Rails.logger.info "Dataset Create Action"
    Rails.logger.info "column_selection present? #{params[:column_selection].present?}"
    Rails.logger.info "column_selection value: #{params[:column_selection].inspect}"
    Rails.logger.info "full_schema present? #{params[:full_schema].present?}"
    Rails.logger.info "full_schema keys: #{params[:full_schema]&.keys&.inspect}"
    Rails.logger.info "dataset params: #{params[:dataset].inspect}"
    Rails.logger.info "=" * 80 + "\n"

    @dataset = Dataset.new(dataset_params)
    authorize @dataset

    # Handle column selection and build schema
    if params[:column_selection].present? && params[:full_schema].present?
      # Validate that at least one column is selected
      if params[:column_selection].empty?
        @dataset.errors.add(:base, "You must select at least one column")
      else
        # Build schema with only selected columns
        selected_indices = params[:column_selection].map(&:to_i)
        begin
          all_columns = params[:full_schema].values.map { |json_str| JSON.parse(json_str) }
          selected_columns = selected_indices.map { |idx| all_columns[idx] }.compact

          Rails.logger.info "Selected columns: #{selected_columns.inspect}"
          @dataset.schema = { "columns" => selected_columns }
        rescue JSON::ParserError => e
          Rails.logger.error("Failed to parse column schema: #{e.message}")
          Rails.logger.error("full_schema values: #{params[:full_schema].values.inspect}")
          @dataset.errors.add(:base, "Invalid column data. Please try again.")
        end
      end
    elsif params[:dataset][:schema].present? && params[:dataset][:schema].is_a?(String)
      # Parse schema JSON if it came as a string from the form (backward compatibility)
      begin
        @dataset.schema = JSON.parse(params[:dataset][:schema])
      rescue JSON::ParserError => e
        Rails.logger.error("Failed to parse schema JSON: #{e.message}")
        @dataset.errors.add(:base, "Invalid schema format. Please try again.")
      end
    end

    if @dataset.errors.empty? && @dataset.save
      redirect_to @dataset, notice: "Dataset was successfully created."
    else
      @connectors = Connector.all.order(:name)

      # Reconstruct table schema from full_schema params if available
      if params[:full_schema].present?
        begin
          all_columns = params[:full_schema].values.map { |json_str| JSON.parse(json_str) }
          @table_schema = {
            columns: all_columns,
            schema: @dataset.schema_name,
            table: @dataset.table_name,
            database: @dataset.connector&.config&.dig("database")
          }
        rescue JSON::ParserError => e
          Rails.logger.error("Failed to reconstruct table schema: #{e.message}")
          # Try to re-fetch from connector as fallback
          if @dataset.connector_id && @dataset.schema_name && @dataset.table_name
            begin
              connector = Connector.find(@dataset.connector_id)
              @table_schema = connector.adapter.get_table_schema(
                schema_name: @dataset.schema_name,
                table_name: @dataset.table_name
              )
            rescue StandardError => fetch_error
              Rails.logger.error("Failed to fetch schema: #{fetch_error.message}")
              flash.now[:alert] = "Could not reload table schema. Please go back and try again."
            end
          end
        end
      elsif @dataset.connector_id && @dataset.schema_name && @dataset.table_name
        # Try to re-fetch table schema if we have the dataset parameters
        begin
          connector = Connector.find(@dataset.connector_id)
          @table_schema = connector.adapter.get_table_schema(
            schema_name: @dataset.schema_name,
            table_name: @dataset.table_name
          )
        rescue ActiveRecord::RecordNotFound
          flash.now[:alert] = "Connector not found. Please go back and try again."
        rescue StandardError => e
          Rails.logger.error("Failed to fetch schema: #{e.message}")
          flash.now[:alert] = "Could not re-fetch table schema. Please go back and try again."
        end
      end

      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @dataset
    @connectors = Connector.all.order(:name)
  end

  def update
    authorize @dataset
    if @dataset.update(dataset_params)
      redirect_to @dataset, notice: "Dataset was successfully updated."
    else
      @connectors = Connector.all.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @dataset
    @dataset.destroy!
    redirect_to datasets_path, notice: "Dataset was successfully deleted."
  end

  def data
    authorize @dataset
    # Fetch paginated data from the dataset
    page = params[:page] || 1
    per_page = 50

    # Cache key includes dataset ID and page number
    cache_key = "dataset_#{@dataset.id}_data_page_#{page}"

    # Check if refresh is requested
    if params[:refresh] == "true"
      Rails.cache.delete(cache_key)
      Rails.cache.delete("dataset_#{@dataset.id}_data_timestamp")
    end

    # Fetch data with caching (1 hour expiration)
    @rows = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      @dataset.fetch_data(page: page.to_i, per_page: per_page)
    end

    # Store timestamp when data was first cached
    @cache_timestamp = Rails.cache.fetch("dataset_#{@dataset.id}_data_timestamp", expires_in: 1.hour) do
      Time.current
    end

    @pagy = Pagy.new(count: @dataset.total_rows, page: page.to_i, limit: per_page)
  end

  private

  def set_dataset
    @dataset = Dataset.find(params[:id])
  end

  def dataset_params
    params.require(:dataset).permit(:name, :description, :table_name, :schema_name, :connector_id, :status, :row_count, :last_updated_at, schema: {})
  end
end
