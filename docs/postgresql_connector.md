# PostgreSQL Connector

## Overview

The PostgreSQL connector allows Alice to connect to PostgreSQL databases as data sources for pipelines. This enables you to:

- Read data from PostgreSQL tables using SQL queries
- Write transformed data to PostgreSQL tables
- Perform aggregations and transformations on PostgreSQL data
- Join PostgreSQL data with other sources (Snowflake, CSV, Excel, etc.)

This connector aligns with **Use Case 4: Daily Sales Aggregation** from the MVP documentation, enabling daily summaries of transactional data from PostgreSQL databases.

## Features

- ✅ **Full CRUD Operations**: Read and write data to/from PostgreSQL
- ✅ **Connection Testing**: Verify connections before saving
- ✅ **Schema Support**: Custom schema selection (defaults to 'public')
- ✅ **SQL Query Support**: Execute arbitrary SQL SELECT queries
- ✅ **Parameterized Queries**: Secure SQL injection prevention
- ✅ **Batch Operations**: Efficient bulk insert operations
- ✅ **Schema Introspection**: Automatic table schema detection

## Configuration

### Required Fields

- **Host**: Server hostname or IP address (e.g., `localhost`, `192.168.1.100`, `db.example.com`)
- **Port**: Port number (default: `5432`)
- **Database**: Database name to connect to
- **Username**: PostgreSQL username
- **Password**: PostgreSQL password

### Optional Fields

- **Schema**: Schema to use (default: `public`)

## Usage

### Creating a PostgreSQL Connector

1. Navigate to **Connectors** in the Alice UI
2. Click **New Connector**
3. Select **PostgreSQL** from the connector type options
4. Fill in the connection details:
   - Name: Give your connector a descriptive name (e.g., "Production PostgreSQL")
   - Host: Your PostgreSQL server address
   - Port: Default is 5432
   - Database: Your database name
   - Username: PostgreSQL user
   - Password: User password
   - Schema (optional): Specify a schema or use the default 'public'
5. Click **Next** to review your settings
6. Click **Create Connector** to test the connection and save

### Using in a Pipeline

Once created, the PostgreSQL connector can be used as a source in pipelines:

1. Create a new pipeline
2. Select your PostgreSQL connector as a source
3. Write a SQL query to extract data:

```sql
SELECT 
  CAST(order_date AS DATE) AS sale_date,
  product_category,
  COUNT(DISTINCT order_id) AS number_of_orders,
  SUM(quantity) AS units_sold,
  SUM(price * quantity) AS total_revenue
FROM line_items
WHERE order_date >= CURRENT_DATE - INTERVAL '1 day' 
  AND order_date < CURRENT_DATE
GROUP BY 1, 2
```

4. Transform the data in DuckDB (optional)
5. Write to your destination (Snowflake, CSV, Excel, etc.)

## Implementation Details

### Adapter: `ConnectorAdapters::PostgresqlAdapter`

The PostgreSQL adapter is located at:
```
app/services/connector_adapters/postgresql_adapter.rb
```

#### Key Methods

- **`test_connection`**: Verifies the connection to PostgreSQL
- **`read_data(query:)`**: Executes a SQL query and returns results as an array of hashes
- **`write_data(table_name:, data:, write_disposition:)`**: Writes data to a PostgreSQL table
  - Supports `:append` and `:truncate_and_load` modes
- **`get_schema(table_name:)`**: Returns column definitions for a table
- **`list_tables`**: Returns all tables in the specified schema

### Security

- **Parameterized Queries**: All SQL operations use parameterized queries to prevent SQL injection
- **Connection Pooling**: Each operation opens and closes connections properly
- **Identifier Quoting**: Table and column names are properly quoted using `quote_ident`

### Performance

- **Batch Inserts**: Write operations batch rows (100 per batch) for optimal performance
- **Connection Timeout**: 10-second timeout for connection attempts
- **Efficient Schema Queries**: Uses PostgreSQL's `information_schema` for metadata

## Example Use Cases

### 1. Daily Sales Aggregation (MVP Use Case 4)

Connect to your transactional PostgreSQL database and extract yesterday's sales data:

```sql
SELECT 
  CAST(order_date AS DATE) AS sale_date,
  product_category,
  COUNT(DISTINCT order_id) AS number_of_orders,
  SUM(quantity) AS units_sold,
  SUM(price * quantity) AS total_revenue
FROM line_items
WHERE order_date >= CURRENT_DATE - INTERVAL '1 day' 
  AND order_date < CURRENT_DATE
GROUP BY 1, 2
```

Then transform and load into Snowflake for dashboard consumption.

### 2. Customer Data Replication

Replicate a customer table from PostgreSQL to Snowflake:

```sql
SELECT 
  customer_id,
  first_name,
  last_name,
  email,
  created_at,
  updated_at
FROM customers
WHERE updated_at >= CURRENT_DATE - INTERVAL '1 day'
```

### 3. Joining PostgreSQL with Other Sources

Use PostgreSQL as one of multiple sources in a pipeline:

**Source 1: PostgreSQL** (transactions table)
```sql
SELECT 
  transaction_id,
  customer_id,
  amount,
  transaction_date
FROM transactions
WHERE transaction_date >= CURRENT_DATE - INTERVAL '7 days'
```

**Source 2: CSV** (customer_regions.csv)

**Transform in DuckDB:**
```sql
SELECT 
  t.transaction_id,
  t.customer_id,
  t.amount,
  t.transaction_date,
  c.region
FROM transactions AS t
LEFT JOIN customer_regions AS c ON t.customer_id = c.customer_id
```

## Troubleshooting

### Connection Failed

- Verify the host and port are correct
- Check that PostgreSQL is running and accepting connections
- Ensure your firewall allows connections from the Alice server
- Verify the username and password are correct
- Check that the database exists

### Permission Errors

- Ensure the PostgreSQL user has SELECT permission on the tables
- For write operations, ensure INSERT, UPDATE, or TRUNCATE permissions as needed
- Verify the user has access to the specified schema

### Schema Not Found

- Check that the schema exists in the database
- Verify schema name spelling (case-sensitive)
- Use `public` schema if unsure

## Technical Notes

- Uses the `pg` gem (already in Gemfile)
- Connections are opened per-operation and closed automatically
- Supports all PostgreSQL data types via string coercion
- Compatible with PostgreSQL 9.6+

## PGLake/Iceberg Features

When `enable_pglake` is set to `true` in the connector configuration, Alice supports advanced data lake features through PGLake extensions.

### Foreign Tables for S3 Access

PGLake uses **foreign tables** to access data in S3, not DuckDB-style functions. This provides ACID-compliant access to data lake files.

#### Reading from S3 Parquet Files

```sql
-- Create a foreign table pointing to S3
CREATE FOREIGN TABLE flight_events ()
SERVER pg_lake
OPTIONS (path 's3://my-bucket/data/events.parquet');

-- Query the foreign table like a regular table
SELECT 
  event_date,
  COUNT(*) as event_count,
  AVG(duration) as avg_duration
FROM flight_events
WHERE event_date >= CURRENT_DATE - 30
GROUP BY event_date;
```

**Key Features:**
- Schema auto-detection from Parquet metadata
- Filter pushdown for efficient queries
- JOIN with regular PostgreSQL tables
- Supports nested/complex Parquet structures

#### Writing to S3

Create writable foreign tables to export data to S3:

```sql
-- Create writable foreign table
CREATE FOREIGN TABLE export_results (
  station VARCHAR(100),
  event_count BIGINT,
  total_cost NUMERIC(15,2)
)
SERVER pg_lake
OPTIONS (
  location 's3://my-bucket/exports/summary/',
  format 'parquet',
  writable 'true'
);

-- Insert data (writes to S3 as Parquet)
INSERT INTO export_results
SELECT 
  station,
  COUNT(*) as event_count,
  SUM(cost) as total_cost
FROM source_table
GROUP BY station;
```

### Iceberg Tables

When Iceberg is configured, you can create transactional data lake tables:

```sql
-- Create Iceberg table
CREATE TABLE analytics_summary (
  date DATE,
  metric_name VARCHAR(100),
  value NUMERIC(15,2),
  updated_at TIMESTAMP
) USING iceberg;

-- Data is stored in S3 with full ACID support
INSERT INTO analytics_summary VALUES
  (CURRENT_DATE, 'daily_revenue', 150000.00, NOW());

-- Updates and deletes work transactionally
UPDATE analytics_summary
SET value = value * 1.1
WHERE date = CURRENT_DATE;
```

**Iceberg Benefits:**
- Time travel (query historical snapshots)
- ACID transactions on data lake
- Schema evolution
- Hidden partitioning

### PGLake Configuration

PGLake connectors support per-instance configuration:

```ruby
{
  "host" => "pglake.example.com",
  "database" => "analytics",
  "username" => "alice",
  "password" => "secret",
  "enable_pglake" => "true",
  
  # S3 Configuration
  "s3_endpoint" => "https://s3.us-east-1.amazonaws.com",  # Optional: for MinIO/custom S3
  "aws_access_key_id" => "AKIAIOSFODNN7EXAMPLE",          # Optional: uses AWS chain if not provided
  "aws_secret_access_key" => "wJalrXUtnFEMI/K7MDENG",     # Optional
  "aws_region" => "us-east-1",
  "s3_bucket" => "my-data-lake",                          # Default bucket
  "s3_use_ssl" => "true",                                  # Default: true
  
  # Iceberg Configuration
  "iceberg_location_prefix" => "s3://my-data-lake/iceberg/"  # Where Iceberg tables are stored
}
```

**Multiple Instances:** Each connector can have different S3 endpoints and Iceberg locations. Configuration is applied per-session, allowing simultaneous connections to multiple PGLake instances.

### Using PGLake in Pipelines

**Example: S3 Parquet → Transform → Iceberg Table**

```sql
-- In your pipeline transformation SQL:

-- Read from S3 Parquet via foreign table
CREATE FOREIGN TABLE source_events ()
SERVER pg_lake
OPTIONS (path 's3://raw-data/events/2024/*.parquet');

-- Transform and write to Iceberg table
INSERT INTO analytics.daily_summary
SELECT 
  DATE(event_timestamp) as date,
  event_type,
  COUNT(*) as event_count,
  AVG(duration) as avg_duration
FROM source_events
WHERE event_timestamp >= CURRENT_DATE - 1
GROUP BY DATE(event_timestamp), event_type;
```

### Limitations

- Foreign table creation requires appropriate S3 permissions
- Iceberg tables require `iceberg_location_prefix` configuration
- Writable foreign tables need explicit column definitions
- Some PGLake features may vary by version

## Future Enhancements

Potential improvements for future versions:

- [ ] SSL/TLS connection support
- [ ] Connection pooling for better performance
- [ ] MERGE write disposition (UPSERT operations)
- [ ] SSH tunnel support for secure connections
- [ ] Query timeout configuration
- [ ] Read-only mode option
- [ ] Support for PostgreSQL arrays and JSON columns
- [ ] UI helpers for creating PGLake foreign tables
- [ ] PGLake version detection and feature compatibility
