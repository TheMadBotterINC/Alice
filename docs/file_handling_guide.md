# File Handling in Alice

## Two Different File Systems (Don't Confuse Them!)

### 1. File Connectors (CSV/Excel) 
**Purpose:** Read files as SOURCE data

**Two Modes:**

#### A) **Upload File Mode** (Recommended for user files)
- Users upload files from their local machine
- File provided when running the pipeline
- Perfect for ad-hoc analysis
- **Direction**: User's Computer → Upload → Pipeline (INPUT)

#### B) **Read from Server Path Mode**
- Read files already on the server
- For automated/scheduled pipelines
- Reads from network shares, SFTP drops, etc.
- **Direction**: Server File → Pipeline (INPUT)

**Configuration:**
- **Upload Mode**: No file path needed, file uploaded at run time
- **File Path Mode**: Server-side absolute path (e.g., `/var/data/sales.csv`)

**Example Workflow (Upload Mode):**
```
1. Create connector: "Upload Sales Data" (CSV, upload mode)
2. Configure: delimiter, headers, etc.
3. Create pipeline using this connector as source
4. Click "Run with Files" button
5. Upload your sales.csv file
6. Pipeline processes your uploaded file
7. Results written to destination or downloaded
```

**Example Workflow (File Path Mode):**
```
1. CSV file exists on server at: /home/mike/data/uploads/sales.csv
2. Create file connector with path: /home/mike/data/uploads/sales.csv
3. Use connector as SOURCE in pipeline
4. Click "Run Now" (no upload needed)
5. Pipeline reads the CSV and transforms data
6. Write results to database or generate new export
```

**When to Use:**
- ✅ Reading uploaded data files
- ✅ Processing files from SFTP/network shares
- ✅ Batch importing data from file systems
- ✅ ETL jobs reading from file drops

**When NOT to Use:**
- ❌ User file downloads (use File Export instead!)
- ❌ Generating reports for users
- ❌ Dynamic file creation

---

### 2. File Export (CSV/Excel Downloads)
**Purpose:** Generate files FOR users to download

**Use Case:**
- Exporting query results as CSV/Excel
- Generating reports for download
- Sharing data with end users

**Configuration:**
- **Export Format**: CSV or Excel
- **Options**: Headers, delimiter, sheet name, etc.
- **Direction**: Pipeline → User Download (OUTPUT)

**Example Workflow:**
```
1. Create pipeline with transformation SQL
2. Set destination to "Download File (CSV/Excel export)"
3. Choose format and options
4. Run pipeline
5. File generated and attached to pipeline run
6. User clicks download button to get file
```

**When to Use:**
- ✅ User downloads/exports
- ✅ Report generation
- ✅ Sharing query results
- ✅ Data extracts for business users

**When NOT to Use:**
- ❌ Reading existing files (use File Connector instead!)
- ❌ Processing server-side files
- ❌ Batch imports

---

## Quick Decision Guide

**Question: Where is the file?**

### File Already Exists (on server):
→ Use **File Connector** as SOURCE
- Example: Reading `/var/data/uploads/monthly_sales.csv`

### File Needs to Be Created (for download):
→ Use **File Export** as DESTINATION  
- Example: Exporting query results to CSV for user

---

## Technical Details

### File Connector Architecture:
```
[Server File System]
        ↓
  [File Connector]
        ↓
    [Pipeline]
        ↓
  [Transformation]
        ↓
   [Destination]
```

### File Export Architecture:
```
    [Pipeline]
        ↓
  [Transformation]
        ↓
  [File Export Logic]
        ↓
  [Temp File Created]
        ↓
 [ActiveStorage Attachment]
        ↓
   [User Download]
```

---

## Common Patterns

### Pattern 1: File → Database
```
File Connector (SOURCE) → Transform → Dataset (DESTINATION)
```
Reading a CSV from server and loading into Snowflake.

### Pattern 2: Database → File
```
Snowflake Connector (SOURCE) → Transform → File Export (DESTINATION)
```
Querying Snowflake and exporting results for download.

### Pattern 3: File → Transform → File
```
File Connector (SOURCE) → Transform → File Export (DESTINATION)
```
Reading a CSV, transforming it, exporting new CSV for download.

### Pattern 4: Multiple Sources → File
```
Multiple Connectors (SOURCE) → Join/Aggregate → File Export (DESTINATION)
```
Combining data from multiple sources into one download.

### Pattern 5: User Upload → Transform → Download
```
Upload Connector (SOURCE) → Transform → File Export (DESTINATION)
```
**Use Case**: User uploads their Excel file, pipeline cleans/transforms it, user downloads cleaned CSV.
**Example**: Data cleanup service, format converter, report generator.

---

## FAQs

**Q: Can file connectors write to user machines?**
A: No. File connectors work with server-side paths only. Use File Export for user downloads.

**Q: Where are File Export files stored?**
A: Via ActiveStorage in `storage/` directory by default (configurable for S3/cloud).

**Q: How do I let users upload files for processing?**
A: Use File Connector in Upload Mode. When running the pipeline, users select file(s) from their computer.

**Q: How do I share pipeline results with users?**
A: Use File Export destination. Results are downloadable via the pipeline show page.

**Q: Can File Connectors read from URLs?**
A: Not directly. You'd need to download the file to server first, then use File Connector.

---

## Security Considerations

### File Connectors:
- ⚠️ Only use paths the Rails app has permission to read
- ⚠️ Validate paths to prevent directory traversal
- ⚠️ Don't expose server file system structure to users

### File Exports:
- ✅ Files are user-scoped via pipeline runs
- ✅ Downloads require authentication
- ✅ Files can be configured to expire
- ✅ Uses Rails' ActiveStorage security model
