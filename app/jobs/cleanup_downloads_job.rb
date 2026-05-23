class CleanupDownloadsJob < ApplicationJob
  queue_as :default

  # Clean up downloaded files older than the retention period
  # By default, keep files for 7 days
  def perform(retention_days: 7)
    Rails.logger.info "Starting cleanup of downloaded files older than #{retention_days} days"

    downloads_dir = Rails.root.join("storage", "downloads")
    return unless Dir.exist?(downloads_dir)

    cutoff_time = retention_days.days.ago
    files_deleted = 0
    space_freed = 0

    # Find all files in downloads directory
    Dir.glob(File.join(downloads_dir, "*")).each do |file_path|
      # Skip directories and .keep file
      next if File.directory?(file_path) || File.basename(file_path) == ".keep"

      # Check if file is older than retention period
      if File.mtime(file_path) < cutoff_time
        file_size = File.size(file_path)

        begin
          File.delete(file_path)
          files_deleted += 1
          space_freed += file_size
          Rails.logger.info "Deleted old download file: #{File.basename(file_path)} (#{format_file_size(file_size)})"
        rescue StandardError => e
          Rails.logger.error "Failed to delete file #{file_path}: #{e.message}"
        end
      end
    end

    Rails.logger.info "Cleanup complete: #{files_deleted} files deleted, #{format_file_size(space_freed)} freed"

    {
      files_deleted: files_deleted,
      space_freed: space_freed
    }
  end

  private

  def format_file_size(bytes)
    if bytes < 1024
      "#{bytes} B"
    elsif bytes < 1024 * 1024
      "#{(bytes / 1024.0).round(2)} KB"
    elsif bytes < 1024 * 1024 * 1024
      "#{(bytes / (1024.0 * 1024)).round(2)} MB"
    else
      "#{(bytes / (1024.0 * 1024 * 1024)).round(2)} GB"
    end
  end
end
