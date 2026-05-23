class RemoveDownloadFilePathFromPipelineRuns < ActiveRecord::Migration[8.0]
  def change
    remove_column :pipeline_runs, :download_file_path, :string
  end
end
