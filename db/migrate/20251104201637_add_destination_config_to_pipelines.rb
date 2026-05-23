class AddDestinationConfigToPipelines < ActiveRecord::Migration[8.0]
  def change
    add_column :pipelines, :destination_config, :jsonb, default: {}, null: false
  end
end
