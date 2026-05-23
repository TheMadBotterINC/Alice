class PipelinesController < ApplicationController
  before_action :set_pipeline, only: [ :show, :edit, :update, :destroy, :run, :preview_transformation, :save_as_template_form, :save_as_template, :visual_builder, :update_from_visual_builder ]

  def index
    @pipelines = Pipeline.includes(:source_connectors, :destination_connector, :destination_dataset).recent
    authorize Pipeline
  end

  def show
    authorize @pipeline
    @pipeline_runs = @pipeline.pipeline_runs.recent.limit(20)
  end

  def new
    @pipeline = Pipeline.new
    authorize @pipeline
    @connectors = Connector.all.order(:name)
    @datasets = Dataset.readable.order(:name)

    # Pre-select a dataset if source_dataset_id parameter is provided
    if params[:source_dataset_id].present?
      dataset = Dataset.find_by(id: params[:source_dataset_id])
      if dataset
        @pipeline.pipeline_sources.build(dataset: dataset)
        @preselected_dataset = dataset
      end
    end
  end

  def create
    @pipeline = Pipeline.new(pipeline_params.except(:source_connector_ids, :source_dataset_ids, :connector_tables))
    authorize @pipeline

    # Handle source connector associations with automatic dataset creation
    if params[:pipeline][:source_connector_ids].present?
      source_ids = params[:pipeline][:source_connector_ids].reject(&:blank?)
      connector_tables = params[:pipeline][:connector_tables] || {}

      source_ids.each do |connector_id|
        connector = Connector.find_by(id: connector_id)
        next unless connector

        # For file connectors, use connector directly
        if connector.file_connector?
          @pipeline.pipeline_sources.build(connector_id: connector_id)
        else
          # For database connectors (Snowflake), find or create dataset
          table_info = connector_tables[connector_id.to_s]
          if table_info.present?
            schema_name = table_info["schema"]
            table_name = table_info["table"]

            if schema_name.present? && table_name.present?
              dataset = find_or_create_dataset(connector, schema_name, table_name)
              @pipeline.pipeline_sources.build(dataset_id: dataset.id) if dataset
            end
          end
        end
      end
    end

    # Handle source dataset associations
    if params[:pipeline][:source_dataset_ids].present?
      source_ids = params[:pipeline][:source_dataset_ids].reject(&:blank?)
      source_ids.each do |dataset_id|
        @pipeline.pipeline_sources.build(dataset_id: dataset_id)
      end
    end

    if @pipeline.save
      redirect_to @pipeline, notice: "Pipeline was successfully created."
    else
      @connectors = Connector.all.order(:name)
      @datasets = Dataset.readable.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @pipeline
    @connectors = Connector.all.order(:name)
    @datasets = Dataset.readable.order(:name)
  end

  def update
    authorize @pipeline
    # Remove old associations first
    @pipeline.pipeline_sources.destroy_all

    # Handle source connector associations update with automatic dataset creation
    if params[:pipeline][:source_connector_ids].present?
      source_ids = params[:pipeline][:source_connector_ids].reject(&:blank?)
      connector_tables = params[:pipeline][:connector_tables] || {}

      source_ids.each do |connector_id|
        connector = Connector.find_by(id: connector_id)
        next unless connector

        # For file connectors, use connector directly
        if connector.file_connector?
          @pipeline.pipeline_sources.create(connector_id: connector_id)
        else
          # For database connectors (Snowflake), find or create dataset
          table_info = connector_tables[connector_id.to_s]
          if table_info.present?
            schema_name = table_info["schema"]
            table_name = table_info["table"]

            if schema_name.present? && table_name.present?
              dataset = find_or_create_dataset(connector, schema_name, table_name)
              @pipeline.pipeline_sources.create(dataset_id: dataset.id) if dataset
            end
          end
        end
      end
    end

    # Handle source dataset associations update
    if params[:pipeline][:source_dataset_ids].present?
      source_ids = params[:pipeline][:source_dataset_ids].reject(&:blank?)
      source_ids.each do |dataset_id|
        @pipeline.pipeline_sources.create(dataset_id: dataset_id)
      end
    end

    if @pipeline.update(pipeline_params.except(:source_connector_ids, :source_dataset_ids, :connector_tables))
      redirect_to @pipeline, notice: "Pipeline was successfully updated."
    else
      @connectors = Connector.all.order(:name)
      @datasets = Dataset.readable.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @pipeline
    @pipeline.destroy!
    redirect_to pipelines_path, notice: "Pipeline was successfully deleted."
  end

  def run
    authorize @pipeline
    # Create a new pipeline run
    pipeline_run = @pipeline.pipeline_runs.create!(
      status: :pending,
      started_at: Time.current
    )

    # Attach any uploaded source files
    if params[:source_files].present?
      params[:source_files].each do |file|
        pipeline_run.source_files.attach(file) if file.present?
      end
    end

    # Enqueue the execution job
    PipelineExecutionJob.perform_later(pipeline_run.id)

    redirect_to @pipeline, notice: "Pipeline run has been queued and will execute shortly."
  end

  def visual_builder
    authorize @pipeline, :update?
    
    # Visual builder only works for pipelines in visual mode
    if @pipeline.sql_mode?
      redirect_to edit_pipeline_path(@pipeline), alert: "Visual Builder is only available for pipelines created in visual mode. This pipeline uses SQL mode."
      return
    end
    
    # Renders the full-page visual query builder for existing pipelines
  end

  def new_visual_builder
    @pipeline = Pipeline.new
    authorize @pipeline
    
    # Pre-populate from session if user is coming back from form
    if session[:draft_pipeline].present?
      draft = session[:draft_pipeline]
      @pipeline.name = draft['name']
      @pipeline.description = draft['description']
      @pipeline.transformation_config = draft['transformation_config']
    end
    
    render :visual_builder
  end

  def create_from_visual_builder
    @pipeline = Pipeline.new(visual_builder_params)
    authorize @pipeline
    
    # Handle source associations (if any were set in session)
    if session[:draft_pipeline].present?
      draft = session[:draft_pipeline]
      
      # Handle source connectors
      if draft['source_connector_ids'].present?
        draft['source_connector_ids'].reject(&:blank?).each do |connector_id|
          @pipeline.pipeline_sources.build(connector_id: connector_id)
        end
      end
      
      # Handle source datasets
      if draft['source_dataset_ids'].present?
        draft['source_dataset_ids'].reject(&:blank?).each do |dataset_id|
          @pipeline.pipeline_sources.build(dataset_id: dataset_id)
        end
      end
    end
    
    if @pipeline.save
      session.delete(:draft_pipeline)
      redirect_to @pipeline, notice: "Pipeline was successfully created."
    else
      render :visual_builder, status: :unprocessable_entity
    end
  end

  def update_from_visual_builder
    authorize @pipeline
    
    if @pipeline.update(visual_builder_params)
      redirect_to @pipeline, notice: "Pipeline was successfully updated."
    else
      render :visual_builder, status: :unprocessable_entity
    end
  end

  def preview_transformation
    authorize @pipeline, :update?

    # Get transformation config from params (visual mode) or SQL (sql mode)
    config = params[:transformation_config]
    
    if config.present?
      # Visual mode: generate SQL from config
      begin
        service = TransformationConfigService.new(config)
        sql = service.to_sql
      rescue TransformationConfigService::ConfigurationError => e
        render json: { error: e.message }, status: :unprocessable_entity
        return
      end
    else
      # SQL mode: use provided SQL
      sql = params[:transformation_sql]
      if sql.blank?
        render json: { error: "No transformation SQL or config provided" }, status: :unprocessable_entity
        return
      end
    end

    # Add LIMIT 10 to preview query if not already present
    sql = "#{sql.strip}\nLIMIT 10" unless sql.match?(/LIMIT\s+\d+/i)

    # Return SQL and preview data
    render json: {
      sql: sql,
      preview: { message: "Preview execution coming in Phase 2" }
    }
  rescue => e
    render json: { error: e.message }, status: :internal_server_error
  end

  # Template actions
  def templates
    authorize Pipeline
    @templates = Pipeline.templates.includes(:source_connectors, :source_datasets).recent
  end

  def save_as_template_form
    authorize @pipeline
    # Renders the modal form
  end

  def save_as_template
    authorize @pipeline
    template_name = params[:template_name]

    if template_name.blank?
      redirect_to @pipeline, alert: "Template name cannot be blank."
      return
    end

    template = @pipeline.save_as_template!(template_name)
    redirect_to templates_pipelines_path, notice: "Pipeline saved as template '#{template.name}'."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @pipeline, alert: "Failed to save as template: #{e.message}"
  end

  def new_from_template
    authorize Pipeline
    @template = Pipeline.templates.find(params[:template_id])
    @pipeline = Pipeline.new
    @connectors = Connector.all.order(:name)
    @datasets = Dataset.readable.order(:name)
    render :new
  end

  def create_from_template
    authorize Pipeline, :create_from_template?
    template = Pipeline.templates.find(params[:template_id])
    pipeline_name = params[:pipeline_name]
    schedule = params[:schedule]

    if pipeline_name.blank?
      redirect_to templates_pipelines_path, alert: "Pipeline name cannot be blank."
      return
    end

    pipeline = template.create_from_template(new_name: pipeline_name, schedule: schedule)
    redirect_to pipeline, notice: "Pipeline '#{pipeline.name}' created from template."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to templates_pipelines_path, alert: "Failed to create pipeline: #{e.message}"
  end

  private

  def set_pipeline
    @pipeline = Pipeline.includes(:source_connectors, :destination_connector, :destination_dataset).find(params[:id])
  end

  def pipeline_params
    params.require(:pipeline).permit(
      :name,
      :description,
      :destination_connector_id,
      :destination_dataset_id,
      :transformation_sql,
      :transformation_mode,
      :transformation_config,
      :schedule,
      :write_disposition,
      :merge_key,
      :export_format,
      :source_row_limit,
      source_connector_ids: [],
      source_dataset_ids: [],
      export_options: {},
      connector_tables: {},
      destination_config: {}
    )
  end

  def visual_builder_params
    params.require(:pipeline).permit(
      :name,
      :description,
      :transformation_mode,
      :transformation_config
    )
  end

  def find_or_create_dataset(connector, schema_name, table_name)
    # Try to find existing dataset
    dataset = Dataset.find_by(
      connector: connector,
      schema_name: schema_name,
      table_name: table_name
    )

    return dataset if dataset.present?

    # Create new dataset if it doesn't exist
    # Use just schema.table for cleaner DuckDB table names
    dataset_name = "#{schema_name}.#{table_name}"

    # If that name exists, make it unique by adding connector name
    if Dataset.exists?(name: dataset_name)
      dataset_name = "#{connector.name} - #{schema_name}.#{table_name}"
    end

    dataset = Dataset.create(
      name: dataset_name,
      connector: connector,
      schema_name: schema_name,
      table_name: table_name,
      status: :active,
      description: "Auto-created from pipeline source"
    )

    Rails.logger.info("Created dataset: #{dataset_name} (ID: #{dataset.id})")
    dataset
  rescue => e
    Rails.logger.error("Failed to create dataset: #{e.message}")
    nil
  end
end
