class CreatePipelineRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :pipeline_runs do |t|
      t.references :pipeline, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.integer :duration
      t.integer :row_count, default: 0
      t.text :error_message
      t.text :logs

      t.timestamps
    end

    add_index :pipeline_runs, :status
    add_index :pipeline_runs, :started_at
    add_index :pipeline_runs, [ :pipeline_id, :started_at ]
  end
end
