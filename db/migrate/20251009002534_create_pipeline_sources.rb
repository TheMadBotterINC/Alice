class CreatePipelineSources < ActiveRecord::Migration[8.0]
  def change
    create_table :pipeline_sources do |t|
      t.references :pipeline, null: false, foreign_key: true
      t.references :connector, null: false, foreign_key: true
      t.string :table_alias

      t.timestamps
    end
  end
end
