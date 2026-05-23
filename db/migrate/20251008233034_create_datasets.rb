class CreateDatasets < ActiveRecord::Migration[8.0]
  def change
    create_table :datasets do |t|
      t.string :name
      t.text :description
      t.string :table_name
      t.jsonb :schema
      t.references :connector, null: false, foreign_key: true
      t.integer :row_count
      t.datetime :last_updated_at
      t.integer :status

      t.timestamps
    end
  end
end
