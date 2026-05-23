class AddWriteModeToDatasets < ActiveRecord::Migration[8.0]
  def change
    add_column :datasets, :write_mode, :integer
  end
end
