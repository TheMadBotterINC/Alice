class AddSourceRowLimitToPipelines < ActiveRecord::Migration[8.0]
  def change
    add_column :pipelines, :source_row_limit, :integer, default: 100000, null: false,
               comment: "Maximum number of rows to load from dataset sources (prevents Snowflake API timeouts)"
  end
end
