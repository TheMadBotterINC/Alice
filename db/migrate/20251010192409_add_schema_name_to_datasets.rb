class AddSchemaNameToDatasets < ActiveRecord::Migration[8.0]
  def change
    add_column :datasets, :schema_name, :string
  end
end
