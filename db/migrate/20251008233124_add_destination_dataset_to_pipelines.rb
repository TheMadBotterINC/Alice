class AddDestinationDatasetToPipelines < ActiveRecord::Migration[8.0]
  def change
    add_reference :pipelines, :destination_dataset, null: true, foreign_key: { to_table: :datasets }
  end
end
