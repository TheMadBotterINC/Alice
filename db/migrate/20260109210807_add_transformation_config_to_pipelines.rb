class AddTransformationConfigToPipelines < ActiveRecord::Migration[8.0]
  def change
    add_column :pipelines, :transformation_config, :jsonb
    add_column :pipelines, :transformation_mode, :string, default: "sql", null: false
  end
end
