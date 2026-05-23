# File Upload Connector Type

## Overview

The `file_upload` connector type allows users to upload files during pipeline execution with automatic format detection. This provides a unified interface for handling CSV, TSV, and Excel files without requiring users to specify the format upfront.

## Features

### 1. **Auto-Format Detection**
The system automatically detects the file format based on:
- File extension (`.csv`, `.tsv`, `.txt`, `.xlsx`, `.xls`)
- File content analysis (for ambiguous cases like `.txt` files)

Supported formats:
- CSV (Comma-Separated Values)
- TSV (Tab-Separated Values)
- Excel (.xlsx, .xls, .xlsm)

### 2. **Upload at Pipeline Run Time**
Unlike traditional file connectors that read from server-side paths:
- Files are uploaded by users when they run the pipeline
- No server-side file path configuration needed
- Each pipeline run can use a different file

### 3. **Clean UI Integration**
- New connector type card in the wizard with 📤 icon
- Simple configuration (just name the connector)
- Clear indication in pipeline run modal that auto-detection is enabled
- Proper accept attributes for file input to filter supported formats

## Usage

### Creating a File Upload Connector

1. Navigate to Connectors → New Connector
2. Select "File Upload" connector type
3. Give it a descriptive name (e.g., "User Data Upload")
4. Click through the wizard (no additional configuration needed)
5. Create the connector

### Using in a Pipeline

1. Create or edit a pipeline
2. Add the file upload connector as a source
3. When running the pipeline:
   - Click "Run Now"
   - A modal will appear requesting file upload
   - Select your CSV, TSV, or Excel file
   - The system automatically detects and processes the format

## Technical Implementation

### Model Changes (`app/models/connector.rb`)
- Added `file_upload` to valid connector types
- Updated `adapter` method to route `file_upload` to `FileAdapter`
- Validation allows empty config for upload mode (no file_path required)

### Adapter Changes (`app/services/connector_adapters/file_adapter.rb`)
- Enhanced `read_from_uploaded_file` method with auto-detection
- Added `detect_file_format` method that analyzes extension and content
- Updated `test_connection` to always pass for upload mode
- Updated `validate_config!` to skip file_path validation for upload mode

### UI Changes

#### Connector Wizard (`app/views/connectors/new.html.erb`)
- Added new "File Upload" card with auto-detect messaging
- Added configuration form section for file_upload

#### Wizard Controller (`app/javascript/controllers/connector_wizard_controller.js`)
- Added file_upload to field visibility logic
- Added review section showing supported formats
- Updated type formatter

#### Pipeline Run Modal (`app/views/pipelines/show.html.erb`)
- Updated file input accept attribute based on connector type
- For file_upload: accepts `.csv,.tsv,.txt,.xlsx,.xls`
- Display auto-detection badge and format info

## Auto-Detection Logic

The `detect_file_format` method in `FileAdapter`:

```ruby
def detect_file_format(file_path, filename)
  ext = file_extension(file_path).downcase
  
  case ext
  when '.csv'
    :csv
  when '.tsv', '.txt'
    # Check if it's actually TSV by examining first line
    first_line = File.open(file_path, &:readline) rescue ""
    if first_line.include?("\t")
      :tsv
    else
      # Might be CSV with .txt extension
      :csv
    end
  when '.xlsx', '.xls', '.xlsm'
    :excel
  else
    # Try to detect from content
    first_line = File.open(file_path, &:readline) rescue ""
    if first_line.include?("\t")
      :tsv
    elsif first_line.include?(",")
      :csv
    else
      :unknown
    end
  end
end
```

## Benefits Over Separate CSV/Excel Connectors

1. **Simpler UX**: Users don't need to know the file format upfront
2. **Flexibility**: Same connector can handle different formats across runs
3. **Fewer Connectors**: One connector instead of separate CSV and Excel connectors
4. **Better DX**: Cleaner API and less configuration to manage

## Backwards Compatibility

The existing `file_csv` and `file_excel` connector types remain fully functional:
- They continue to support both file_path and upload modes
- Existing connectors are not affected
- Users can choose between specific-format and auto-detect connectors

## Future Enhancements

Potential improvements:
- Support for additional formats (JSON, Parquet, etc.)
- More sophisticated content-based detection
- Configurable delimiter detection for CSV files
- Preview of detected format before processing
- Support for compressed files (.zip, .gz)
