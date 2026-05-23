# Running Pipelines with File Export

## Overview
Pipelines can now export their results as downloadable CSV or Excel files instead of writing to a database destination.

## Setup

### 1. Start the Background Worker

The pipeline execution runs in a background job, so you need the SolidQueue worker running.

**Option A: Via VSCode (Recommended)**
1. Open VSCode
2. Press `F5` or go to Run > Start Debugging
3. Select "Rails Server + Worker" compound configuration
   - This starts both the Rails server AND the worker

**Option B: Via Terminal**
```bash
# In a separate terminal window
bin/rails solid_queue:start
```

**Option C: Using the helper script**
```bash
# In a separate terminal window
bin/solid_queue_worker
```

### 2. Configure Pipeline for File Export

**Via UI:**
1. Go to your pipeline
2. Click "Edit"
3. In the "Destination" section:
   - Select "Download File (CSV/Excel export)"
   - Choose format: CSV or Excel
   - Configure options:
     - **CSV**: delimiter (comma, tab, semicolon, pipe), include headers
     - **Excel**: sheet name, include headers

**Via Console:**
```ruby
# For CSV export
p = Pipeline.find(YOUR_PIPELINE_ID)
p.destination_connector_id = nil
p.destination_dataset_id = nil
p.export_format = 'csv'
p.export_options = {has_header: true, delimiter: ','}
p.save!

# For Excel export
p = Pipeline.find(YOUR_PIPELINE_ID)
p.destination_connector_id = nil
p.destination_dataset_id = nil
p.export_format = 'excel'
p.export_options = {has_header: true, sheet_name: 'Data'}
p.save!
```

### 3. Run the Pipeline

1. Navigate to the pipeline page
2. Click "Run Now"
3. Wait for execution to complete
4. The page will show a download button with the filename

## File Download

Once a pipeline run completes successfully, you'll see:
- Download button with file icon
- Filename (e.g., `20251011_025557_my_pipeline.csv`)
- Click to download the file

## Troubleshooting

### Pipeline stuck in "Running" status
- **Cause**: Worker is not running
- **Solution**: Start the worker (see Setup #1)

### No download link appears
- **Cause**: Pipeline not configured for file export
- **Solution**: Check pipeline configuration (see Setup #2)
- Verify: `pipeline.export_format` should be 'csv' or 'excel'

### Worker not processing jobs
- **Cause**: Worker stuck in debugger or not started
- **Check**: `ps aux | grep solid_queue`
- **Fix**: Kill stuck processes and restart worker

### Manual job execution (emergency)
```bash
# Find the pipeline run ID from the UI or database
bin/rails runner "PipelineExecutionJob.perform_now(PIPELINE_RUN_ID)"
```

## Technical Details

### File Storage
- Files are stored via ActiveStorage
- By default: local disk in `storage/` directory
- Can be configured for cloud storage (S3, GCS, Azure)

### Database Schema
- `pipelines.export_format`: 'csv' or 'excel'
- `pipelines.export_options`: JSONB with format-specific options
- `pipeline_runs.output_file`: ActiveStorage attachment

### How It Works
1. User clicks "Run Now"
2. PipelineRun created with status='pending'
3. PipelineExecutionJob queued to SolidQueue
4. Worker picks up job and executes
5. Service generates temp file with results
6. File attached to PipelineRun via ActiveStorage
7. Temp file deleted
8. Download link appears on pipeline page

## Migration from Legacy System

If you have old pipelines using file connectors:
1. Edit the pipeline
2. Remove connector destination
3. Select "Download File" option
4. Configure format and options
5. Save

Old file connectors can still be used as **source** connectors for reading data.
