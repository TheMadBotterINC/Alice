class ConnectorsController < ApplicationController
  before_action :set_connector, only: [ :show, :edit, :update, :destroy, :test_connection, :browse_tables, :available_tables, :table_schema ]

  def index
    @connectors = Connector.recent
    authorize Connector
  end

  def show
    authorize @connector
  end

  def new
    @connector = Connector.new
    authorize @connector
  end

  def create
    @connector = Connector.new(connector_params)
    authorize @connector

    if @connector.save
      redirect_to @connector, notice: "Connector was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @connector
  end

  def update
    authorize @connector
    if @connector.update(connector_params)
      redirect_to @connector, notice: "Connector was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @connector
    # Check for dependencies before attempting deletion
    dependencies = []

    if @connector.pipelines_as_source.any?
      dependencies << "#{@connector.pipelines_as_source.count} pipeline(s) as source"
    end

    if @connector.pipelines_as_destination.any?
      dependencies << "#{@connector.pipelines_as_destination.count} pipeline(s) as destination"
    end

    if @connector.datasets.any?
      dependencies << "#{@connector.datasets.count} dataset(s)"
    end

    if dependencies.any?
      redirect_to @connector, alert: "Cannot delete connector. It is being used by: #{dependencies.join(', ')}. Please remove these dependencies first."
      return
    end

    @connector.destroy!
    redirect_to connectors_path, notice: "Connector was successfully deleted."
  rescue ActiveRecord::InvalidForeignKey => e
    redirect_to @connector, alert: "Cannot delete connector due to existing dependencies. Please remove all pipelines and datasets using this connector first."
  end

  def test_connection
    authorize @connector
    if @connector.test_connection
      redirect_to @connector, notice: "Connection test successful! Connector is now active."
    else
      redirect_to @connector, alert: "Connection test failed: #{@connector.errors.full_messages.join(', ')}"
    end
  end

  def available_tables
    authorize @connector
    unless @connector.connected?
      render json: { success: false, error: "Connector not connected" }, status: :unprocessable_entity
      return
    end

    begin
      cache_key = "connector_#{@connector.id}_available_tables"

      tables = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
        preview = @connector.adapter.get_database_preview
        schemas_preview = preview[:schemas_preview] || []

        schemas_preview.flat_map do |schema_info|
          schema_info[:tables].map do |table|
            {
              schema: schema_info[:schema],
              table: table[:name],
              display: "#{schema_info[:schema]}.#{table[:name]}"
            }
          end
        end
      end

      render json: { success: true, tables: tables }
    rescue => e
      Rails.logger.error("Failed to fetch tables for connector #{@connector.id}: #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end
  end

  def browse_tables
    authorize @connector
    unless @connector.connected?
      redirect_to @connector, alert: "Please test the connection first before browsing tables."
      return
    end

    # Check if we should refresh the cache
    refresh = params[:refresh] == "true"
    cache_key = "connector_#{@connector.id}_database_preview"
    cache_duration = 1.hour

    begin
      @database_preview = if refresh
        # Force refresh - clear cache and fetch fresh data
        Rails.cache.delete(cache_key)
        Rails.logger.info("Fetching fresh database preview for connector #{@connector.id}")
        @connector.adapter.get_database_preview.tap do |preview|
          Rails.cache.write(cache_key, preview, expires_in: cache_duration)
        end
      else
        # Try to use cached data, fetch if not available
        Rails.cache.fetch(cache_key, expires_in: cache_duration) do
          Rails.logger.info("Caching database preview for connector #{@connector.id}")
          @connector.adapter.get_database_preview
        end
      end

      # Store cache timestamp for display
      @cache_timestamp = Rails.cache.read("#{cache_key}_timestamp") || Time.current
      Rails.cache.write("#{cache_key}_timestamp", @cache_timestamp, expires_in: cache_duration) unless refresh
      Rails.cache.write("#{cache_key}_timestamp", Time.current, expires_in: cache_duration) if refresh

    rescue => e
      Rails.cache.delete(cache_key)
      redirect_to @connector, alert: "Failed to fetch tables: #{e.message}"
    end
  end

  def table_schema
    authorize @connector
    unless @connector.connected?
      render json: { success: false, error: "Connector not connected" }, status: :unprocessable_entity
      return
    end

    schema_name = params[:schema_name]
    table_name = params[:table_name]

    unless schema_name.present? && table_name.present?
      render json: { success: false, error: "Schema name and table name are required" }, status: :bad_request
      return
    end

    begin
      cache_key = "connector_#{@connector.id}_table_schema_#{schema_name}_#{table_name}"

      schema_info = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
        @connector.adapter.get_table_schema(schema_name: schema_name, table_name: table_name)
      end

      render json: { success: true, schema: schema_info }
    rescue => e
      Rails.logger.error("Failed to fetch table schema for #{schema_name}.#{table_name}: #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end
  end

  private

  def set_connector
    @connector = Connector.find(params[:id])
  end

  def connector_params
    params.require(:connector).permit(:name, :connector_type, config: {})
  end
end
