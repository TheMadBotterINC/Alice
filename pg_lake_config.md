Here's the connection information for your pg_lake deployment:
## PG Info
Host: 174.138.58.253
Port: 5432
User: postgres
Database: postgres
Password: postgres

PostgreSQL Database
Connect via psql:
bash
Query the parquet data:
sql
MinIO S3 Storage

S3 API Endpoint:
MinIO Web Console:
Credentials:
•  Access Key: minioadmin
•  Secret Key: minioadmin
* Port: 9000

Bucket: opdi

Parquet file location: s3://opdi/flight_list/mro_events.parquet

Data Summary
•  Rows: 50,000 MRO (Maintenance, Repair, Operations) events
•  Columns: event_id, tail_number, event_date, event_type, station, fault_code, downtime_hours, cost_usd
