class AddIsTemplateToPipelines < ActiveRecord::Migration[8.0]
  def change
    add_column :pipelines, :is_template, :boolean, default: false, null: false
    add_index :pipelines, :is_template
  end
end
