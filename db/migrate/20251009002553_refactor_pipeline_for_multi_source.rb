class RefactorPipelineForMultiSource < ActiveRecord::Migration[8.0]
  def change
    # Add new columns
    add_reference :pipelines, :destination_connector, foreign_key: { to_table: :connectors }, index: true
    add_column :pipelines, :write_disposition, :integer, default: 0, null: false

    # Remove old single source reference (data will be lost, fresh start)
    remove_reference :pipelines, :source_connector, foreign_key: { to_table: :connectors }, index: true

    # Remove destination_dataset_id (replaced by destination_connector_id)
    remove_reference :pipelines, :destination_dataset, foreign_key: { to_table: :datasets }, index: true
  end
end
