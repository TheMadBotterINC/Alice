class HomeController < ApplicationController
  def index
    # Fetch dashboard statistics
    @total_pipelines = Pipeline.count
    @total_connectors = Connector.count
    @total_datasets = Dataset.count
    @active_connectors = Connector.active.count

    # Fetch recent pipeline runs (last 5)
    @recent_runs = PipelineRun.includes(:pipeline).recent.limit(5)

    # Get the most recent run for "Last Run" stat
    @last_run = PipelineRun.order(started_at: :desc).first

    # System health - count of failed runs in last 24 hours
    @recent_failures = PipelineRun.where(status: :failed)
                                  .where("started_at >= ?", 24.hours.ago)
                                  .count

    # Chart data: Pipeline execution timeline (last 7 days)
    @execution_timeline = generate_execution_timeline

    # Chart data: Success rate pie chart
    @success_rate_data = generate_success_rate_data

    # Chart data: Top 5 most active pipelines
    @top_pipelines = generate_top_pipelines_data

    # Chart data: Data volume processed (last 30 days)
    @data_volume_trend = generate_data_volume_trend
  end

  private

  def generate_execution_timeline
    # Get pipeline runs for the last 7 days grouped by day and status
    runs_by_day = PipelineRun.where("started_at >= ?", 7.days.ago)
                             .group("DATE(started_at)", :status)
                             .count

    # If no data in last 7 days, use lifetime data grouped by day
    if runs_by_day.empty? && PipelineRun.any?
      runs_by_day = PipelineRun.group("DATE(started_at)", :status).count

      # Get the actual date range of all runs
      first_run = PipelineRun.minimum(:started_at)&.to_date
      last_run = PipelineRun.maximum(:started_at)&.to_date || Date.today

      dates = [ first_run, 6.days.ago.to_date ].compact.min <= 6.days.ago.to_date ?
              (6.days.ago.to_date..last_run).to_a :
              (first_run..last_run).to_a.last(7)
    else
      dates = (6.days.ago.to_date..Date.today).to_a
    end

    # Organize data for Chart.js
    {
      labels: dates.map { |d| d.strftime("%a %m/%d") },
      succeeded: dates.map { |d| runs_by_day[[ d, "succeeded" ]] || 0 },
      failed: dates.map { |d| runs_by_day[[ d, "failed" ]] || 0 },
      running: dates.map { |d| runs_by_day[[ d, "running" ]] || 0 }
    }
  end

  def generate_success_rate_data
    # Count runs by status (last 30 days)
    status_counts = PipelineRun.where("started_at >= ?", 30.days.ago)
                               .group(:status)
                               .count

    # If no data in last 30 days, use lifetime data
    if status_counts.empty? && PipelineRun.any?
      status_counts = PipelineRun.group(:status).count
    end

    {
      succeeded: status_counts["succeeded"] || 0,
      failed: status_counts["failed"] || 0,
      running: status_counts["running"] || 0
    }
  end

  def generate_top_pipelines_data
    # Top 5 pipelines by execution count (last 30 days)
    top = PipelineRun.where("started_at >= ?", 30.days.ago)
                     .group(:pipeline_id)
                     .count
                     .sort_by { |_, count| -count }
                     .first(5)

    # If no data in last 30 days, use lifetime data
    if top.empty? && PipelineRun.any?
      top = PipelineRun.group(:pipeline_id)
                       .count
                       .sort_by { |_, count| -count }
                       .first(5)
    end

    pipeline_ids = top.map(&:first)
    pipelines = Pipeline.where(id: pipeline_ids).index_by(&:id)

    {
      labels: top.map { |id, _| pipelines[id]&.name || "Unknown" },
      data: top.map(&:last)
    }
  end

  def generate_data_volume_trend
    # Data volume processed over last 30 days
    volume_by_day = PipelineRun.where("started_at >= ?", 30.days.ago)
                               .where(status: :succeeded)
                               .group("DATE(started_at)")
                               .sum(:row_count)

    # If no data in last 30 days, use lifetime data
    if volume_by_day.empty? && PipelineRun.where(status: :succeeded).any?
      volume_by_day = PipelineRun.where(status: :succeeded)
                                 .group("DATE(started_at)")
                                 .sum(:row_count)

      # Get the actual date range of succeeded runs
      first_run = PipelineRun.where(status: :succeeded).minimum(:started_at)&.to_date
      last_run = PipelineRun.where(status: :succeeded).maximum(:started_at)&.to_date || Date.today

      dates = first_run && last_run ?
              (first_run..last_run).to_a.last(30) :
              (29.days.ago.to_date..Date.today).to_a
    else
      dates = (29.days.ago.to_date..Date.today).to_a
    end

    {
      labels: dates.map { |d| d.strftime("%m/%d") },
      data: dates.map { |d| volume_by_day[d] || 0 }
    }
  end
end
