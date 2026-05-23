class AddMergeKeyToPipelines < ActiveRecord::Migration[8.0]
  def change
    add_column :pipelines, :merge_key, :string
  end
end
