class AddDownloadFilePathToPipelineRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :pipeline_runs, :download_file_path, :string
  end
end
