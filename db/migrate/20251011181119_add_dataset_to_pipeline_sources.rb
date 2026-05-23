class AddDatasetToPipelineSources < ActiveRecord::Migration[8.0]
  def change
    add_reference :pipeline_sources, :dataset, null: true, foreign_key: true

    # Make connector_id nullable too since sources can now be either connector OR dataset
    change_column_null :pipeline_sources, :connector_id, true

    # Add a check constraint to ensure either connector_id or dataset_id is present
    add_check_constraint :pipeline_sources,
      "(connector_id IS NOT NULL AND dataset_id IS NULL) OR (connector_id IS NULL AND dataset_id IS NOT NULL)",
      name: "pipeline_sources_source_type_check"
  end
end
