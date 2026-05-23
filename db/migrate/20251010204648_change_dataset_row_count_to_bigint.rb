class ChangeDatasetRowCountToBigint < ActiveRecord::Migration[8.0]
  def change
    change_column :datasets, :row_count, :bigint
  end
end
