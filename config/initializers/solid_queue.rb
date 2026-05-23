# Configure Solid Queue for background job processing
# Solid Queue is Rails 8's database-backed job backend

Rails.application.configure do
  # Use Solid Queue as the ActiveJob adapter
  config.active_job.queue_adapter = :solid_queue

  # Optional: Configure default queue for all jobs
  # config.active_job.default_queue_name = :default
end

# Solid Queue uses config/queue.yml for worker configuration
# See config/queue.yml for concurrency and polling settings
