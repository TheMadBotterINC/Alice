class AddFileExportSettingsToPipelines < ActiveRecord::Migration[8.0]
  def change
    add_column :pipelines, :export_format, :string
    add_column :pipelines, :export_options, :jsonb
  end
end
