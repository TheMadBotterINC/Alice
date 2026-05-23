class CreatePipelines < ActiveRecord::Migration[8.0]
  def change
    create_table :pipelines do |t|
      t.string :name, null: false
      t.text :description
      t.bigint :source_connector_id, null: false
      t.text :transformation_sql, null: false
      t.integer :status, null: false, default: 0
      t.string :schedule
      t.datetime :last_run_at

      t.timestamps
    end

    add_index :pipelines, :source_connector_id
    add_index :pipelines, :status
    add_index :pipelines, :name
    add_foreign_key :pipelines, :connectors, column: :source_connector_id
  end
end
