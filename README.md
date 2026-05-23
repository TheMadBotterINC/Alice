# Alice - Managed Data Pipelines

Alice is a modern data pipeline orchestration platform that simplifies ETL/ELT workflows with an intuitive web interface, powerful SQL transformations using DuckDB, and flexible connector architecture.

![Ruby on Rails](https://img.shields.io/badge/Rails-8.0-red)
![Ruby](https://img.shields.io/badge/Ruby-3.4.6-red)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Latest-blue)
![DuckDB](https://img.shields.io/badge/DuckDB-Latest-yellow)

## 🌟 Features

### Core Capabilities
- **Multi-Source Pipelines** - Connect multiple data sources to a single pipeline
- **SQL Transformations** - Use DuckDB's powerful SQL engine for data transformation
- **Visual Pipeline Builder** - Create and manage pipelines through a clean web UI
- **Real-Time SQL Highlighting** - Syntax-highlighted SQL editor with Alice brand colors
- **SQL Validation** - Client and server-side validation for common SQL errors
- **Flexible Scheduling** - Cron-based pipeline execution scheduling
- **Write Dispositions** - Choose between append, truncate_and_load, or merge strategies
- **Pipeline Monitoring** - Track execution history, status, and performance metrics
- **Role-Based Access Control** - Four-tier permission system (Owner/Admin, Data Engineer, Analyst, Viewer)

### Data Connectors
- **Snowflake** - Full support with credential management (requires Datasets for pipelines)
- **PostgreSQL** - Database connector support (requires Datasets for pipelines)
- **CSV Files** - Local file imports (can be used directly)
- **Excel Files** - Excel file imports (can be used directly)
- **DuckDB** - Native DuckDB database support (requires Datasets for pipelines)
- Extensible architecture for adding new connectors

**Important**: Database connectors (Snowflake, PostgreSQL, DuckDB) require you to create a Dataset from a specific table before using it in pipelines. File connectors (CSV, Excel) can be used directly.

### Pipeline Features
- Multiple source connectors per pipeline
- Optional destination connectors (can run transformations without writing)
- Pipeline runs with detailed logs and error tracking
- Success rate calculations
- Real-time status indicators
- Pipeline cloning and templates

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────┐
│                   Web UI                         │
│         (Rails 8 + Tailwind CSS)                │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────┼───────────────────────────────┐
│                 │    Application Layer           │
│   ┌─────────────▼──────────┐                    │
│   │  Pipeline Controller    │                    │
│   └──────────┬──────────────┘                    │
│              │                                    │
│   ┌──────────▼───────────────────┐              │
│   │  Pipeline Execution Service  │              │
│   └──────────┬───────────────────┘              │
└──────────────┼────────────────────────────────────┘
               │
┌──────────────┼────────────────────────────────────┐
│              │       Data Layer                    │
│   ┌──────────▼──────────┐                         │
│   │  Connector Adapters │                         │
│   │  - Snowflake        │                         │
│   │  - CSV              │                         │
│   │  - DuckDB           │                         │
│   └──────────┬──────────┘                         │
│              │                                     │
│   ┌──────────▼──────────┐                         │
│   │   DuckDB Engine     │◄──── Transformation    │
│   │  (In-Memory ETL)    │                         │
│   └─────────────────────┘                         │
└────────────────────────────────────────────────────┘
```

## 🚀 Getting Started

### Prerequisites

- **Ruby**: 3.4.6 or higher
- **Rails**: 8.0.3 or higher  
- **PostgreSQL**: 12 or higher (also used for background jobs via Solid Queue)
- **Node.js**: 18 or higher (for asset compilation)
- **DuckDB**: Automatically installed via gem

### Installation

1. **Clone the repository**
```bash
git clone <repository-url>
cd Alice
```

2. **Install dependencies**
```bash
bundle install
npm install  # or yarn install
```

3. **Set up the database**
```bash
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed  # Optional: Load sample data
```

4. **Configure environment variables**
```bash
cp .env.example .env
# Edit .env with your configuration
```

Required environment variables:
- `DATABASE_URL` - PostgreSQL connection string
- `RAILS_ENV` - Environment (development, test, production)
- `SECRET_KEY_BASE` - Rails secret key (generate with `bin/rails secret`)

5. **Start the application**
```bash
# Terminal 1: Start the web server
bin/rails server

# Terminal 2: Start Solid Queue worker
bundle exec rake solid_queue:start
```

Visit `http://localhost:3000` to access Alice.

**Monitoring Background Jobs:**
View job status in the Rails logs or check the `solid_queue_*` tables in your database for job queue status.

### Default Credentials

After seeding the database:
- **Email**: `admin@example.com`
- **Password**: `password123`

**⚠️ Change these credentials immediately in production!**

## 📖 Usage Guide

### Understanding Datasets

**Important**: Database connectors (Snowflake, PostgreSQL, DuckDB) require you to create Datasets before using them in pipelines. 

A Dataset is a registered table from your database that Alice can query. See the [Datasets Guide](docs/datasets_guide.md) for complete details.

**Quick Start**:
1. Go to your database connector → Click "Browse Tables"
2. Find your table → Click "Create Dataset"
3. Use the Dataset in your pipeline

### Creating Your First Pipeline

1. **Navigate to Pipelines** → Click "New Pipeline"

2. **Configure Basic Settings**
   - **Name**: Give your pipeline a descriptive name
   - **Description**: Optional details about the pipeline's purpose
   - **Schedule**: Optional cron expression (e.g., `0 2 * * *` for daily at 2 AM)

3. **Select Source Connectors**
   - **Database Connectors** (Snowflake, PostgreSQL, DuckDB): You must first create a Dataset from the specific table you want to use
     - Go to Connectors → [Your Connector] → Browse Tables
     - Click "Create Dataset" for the table you want
     - Use the Dataset as your pipeline source
   - **File Connectors** (CSV, Excel): Can be used directly as sources without creating Datasets
   - Data from all sources will be available in your transformation SQL

4. **Write Transformation SQL**
   - Use DuckDB SQL syntax
   - Reference source tables using connector names (sanitized to valid SQL identifiers)
   - Enjoy real-time syntax highlighting with Alice brand colors
   - Get instant validation for common SQL errors

Example transformation:
```sql
WITH daily_aggregates AS (
  SELECT 
    DATE(order_date) as sale_date,
    product_category,
    COUNT(*) as order_count,
    SUM(amount) as total_revenue
  FROM production_snowflake
  WHERE order_date >= CURRENT_DATE - 30
  GROUP BY DATE(order_date), product_category
),
moving_averages AS (
  SELECT
    *,
    AVG(total_revenue) OVER (
      PARTITION BY product_category 
      ORDER BY sale_date 
      ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) as revenue_7day_avg
  FROM daily_aggregates
)
SELECT * FROM moving_averages
ORDER BY sale_date DESC, product_category
```

5. **Configure Destination (Optional)**
   - Select a destination connector to write results
   - Choose write disposition:
     - **Append**: Add new rows to existing data
     - **Truncate and Load**: Replace all existing data
     - **Merge**: Update existing rows, insert new ones
   - Leave empty to run transformations without writing

6. **Save and Run**
   - Click "Create Pipeline"
   - Use "Run Pipeline" to execute immediately
   - Or let the schedule trigger automatic runs

### Managing Connectors

#### Adding a Snowflake Connector

Alice uses Snowflake's SQL REST API for connectivity - **no ODBC driver installation required!**

1. Navigate to **Connectors** → **New Connector**
2. Fill in the form:
   - **Name**: `Production Snowflake`
   - **Type**: Snowflake
   - **Configuration**:
     ```json
     {
       "account": "your-account",
       "username": "your-username",
       "password": "your-password",
       "database": "your-database",
       "warehouse": "your-warehouse",
       "schema": "PUBLIC",
       "role": "ANALYST" (optional)
     }
     ```
3. Click **Test Connection** to verify
4. Save the connector
5. **Create Datasets**: Before using in pipelines, browse tables and create Datasets for specific tables you want to query

**Snowflake Configuration Details:**

- **Account**: Your Snowflake account identifier (e.g., `xy12345.us-east-1`)
- **Username**: Snowflake user with appropriate permissions
- **Password**: User password (stored securely in encrypted database)
- **Database**: Target database name
- **Warehouse**: Compute warehouse to use for queries
- **Schema**: Schema name (defaults to `PUBLIC` if not specified)
- **Role**: Optional role to assume (useful for access control)

**Connection Method:**
Alice uses Snowflake's SQL REST API (`https://account.snowflakecomputing.com/api/v2/statements`), which provides:
- Pure Ruby implementation (no native extensions)
- Automatic query polling and result fetching
- Built-in retry logic for transient failures
- Support for long-running queries
- No ODBC driver dependencies

**Supported Operations:**
- ✅ Read data via SELECT queries
- ✅ Write data with INSERT statements
- ✅ Table truncation for truncate_and_load
- ✅ Schema introspection via DESC TABLE
- ✅ Batch inserts (1000 rows per batch)
- ⚠️ Merge operations (coming soon)

**Performance Tips:**
- Use appropriate warehouse sizes for your workload
- Leverage Snowflake's result caching when possible
- Consider partitioning large datasets
- Use SELECT column lists instead of SELECT *

#### Adding a CSV Connector

1. Navigate to **Connectors** → **New Connector**
2. Configure:
   - **Name**: `Sales Data CSV`
   - **Type**: CSV
   - **Configuration**:
     ```json
     {
       "file_path": "/path/to/data.csv",
       "delimiter": ",",
       "has_header": true
     }
     ```

#### Adding a Looking Glass Connector

Looking Glass is a partner analytics platform that provides custom dashboards for MRO and manufacturing leaders. Alice can send transformed data to Looking Glass via REST API.

1. Navigate to **Connectors** → **New Connector**
2. Fill in the form:
   - **Name**: `Looking Glass Analytics`
   - **Type**: Looking Glass
   - **Configuration**:
     ```json
     {
       "api_url": "https://your-looking-glass.com",
       "api_key": "lg_your_api_key_here",
       "connection_id": "123"
     }
     ```
3. Click **Test Connection** to verify API credentials
4. Save the connector

**Looking Glass Configuration Details:**

- **api_url**: URL of your Looking Glass instance (e.g., `https://analytics.yourdomain.com`)
- **api_key**: API key from your Looking Glass user account
  - Log into Looking Glass → User Profile → API Key
  - Keep this key secure - it provides write access to your customer database
- **connection_id**: The Looking Glass connection ID for the target customer database
  - Found in Looking Glass admin panel → Connections
  - Each connection represents a customer's database

**How It Works:**

1. Alice runs your pipeline transformation using DuckDB
2. Transformed data is sent to Looking Glass API via HTTPS
3. Looking Glass writes data to the specified customer PostgreSQL database
4. Customers see updated dashboards in Looking Glass UI

**Data Format:**
- Small datasets (<1000 rows): Sent as JSON for speed
- Large datasets (≥1000 rows): Sent as CSV for efficiency
- Automatic format selection based on row count

**Write Dispositions:**
- **Append**: Add new rows to existing table
- **Truncate and Load**: Replace all data in table
- **Merge**: Update existing rows (requires primary key - coming soon)

**Important Notes:**
- Looking Glass connectors are destination-only (cannot be used as sources)
- Table will be created automatically if it doesn't exist
- Column types are inferred from the first row of data
- API includes automatic retry logic for transient failures

### Pipeline Scheduling

Alice supports **automatic pipeline execution** using cron expressions via Solid Queue recurring jobs.

#### How Scheduling Works

1. **Define Schedule**: When creating or editing a pipeline, enter a cron expression in the "Schedule" field
2. **Automatic Execution**: A background job (`ScheduledPipelineRunnerJob`) runs every minute
3. **Cron Evaluation**: The job checks all scheduled pipelines and enqueues execution for those due to run
4. **Duplicate Prevention**: Pipelines already running or recently executed are skipped

#### Cron Expression Examples

```bash
# Every day at 2:00 AM
0 2 * * *

# Every 6 hours
0 */6 * * *

# Every Sunday at 3:00 AM
0 3 * * 0

# Every 15 minutes
*/15 * * * *

# Every weekday at 9:00 AM
0 9 * * 1-5

# First day of every month at midnight
0 0 1 * *
```

**Cron Format**: `minute hour day month weekday`
- **minute**: 0-59
- **hour**: 0-23  
- **day**: 1-31
- **month**: 1-12
- **weekday**: 0-7 (0 and 7 are Sunday)

#### Scheduling Features

✅ **Features:**
- Standard cron syntax support via the `fugit` gem
- Automatic duplicate prevention (won't run if already executing)
- Recent run tracking (won't re-run if executed within the last minute)
- Invalid cron expression handling with warnings in logs
- Multiple schedules can run concurrently
- Manual runs work independently of schedule

⚠️ **Important Notes:**
- The scheduler checks every minute - schedules are evaluated at minute boundaries
- Pipelines running longer than their schedule interval will not overlap
- Empty or null schedules mean manual-run-only
- Schedule execution is logged in Rails logs for monitoring

#### Monitoring Scheduled Pipelines

View scheduler activity in Rails logs:
```bash
# Development
tail -f log/development.log | grep "ScheduledPipelineRunnerJob"

# Production
journalctl -u alice -f | grep "ScheduledPipelineRunnerJob"
```

Log messages include:
- Pipelines checked
- Pipelines enqueued for execution
- Skipped pipelines (already running or recently ran)
- Invalid cron expressions
- Errors during scheduling

### Monitoring Pipeline Runs

View pipeline execution details:
- **Status**: Pending, Running, Succeeded, Failed
- **Duration**: Execution time in seconds
- **Row Counts**: Sources loaded, transformation results, destination writes
- **Logs**: Detailed execution logs
- **Error Messages**: Full error context for failed runs
- **Last Run Time**: Timestamp of most recent execution

### SQL Syntax Validation

Alice validates your SQL before execution, catching:
- **Common typos**: SLECT → SELECT, FORM → FROM
- **Unbalanced quotes**: Missing ' or " characters
- **Unbalanced parentheses**: Mismatched ( and )
- **Incomplete clauses**: FROM without table name, WHERE without condition
- **Multiple statements**: Only single statements allowed (prevents SQL injection)
- **Missing FROM**: SELECT must have FROM clause (unless selecting constants)

## 🎨 Design System

Alice uses a custom brand color palette throughout the UI:

- **Primary Dark**: `#1a134a` - Headers, emphasis
- **Primary Blue**: `#27a2d6` - Buttons, links, SQL keywords
- **Secondary Blue**: `#0085bf` - SQL functions
- **Light Blue**: `#44c8f5` - Hover states
- **Pale**: `#ecebd8` - Backgrounds
- **Green**: `#26a74a` - Success states, SQL numbers
- **Red**: `#f04d3f` - Errors, SQL strings
- **Cyan**: `#17a2b9` - Info messages
- **Warning**: `#ffc107` - Warning states

Typography:
- **Primary Font**: Raleway (Google Fonts)
- **Monospace**: System monospace stack for code

## 🔐 Security

### Authentication
- BCrypt password hashing
- Session-based authentication
- Secure session cookies

### Authorization
Four-tier role system:

| Role | Permissions |
|------|-------------|
| **Owner/Admin** | Full system access, user management |
| **Data Engineer** | Create/edit/run pipelines, manage connectors |
| **Analyst** | Create/edit/run pipelines, view connectors |
| **Viewer** | Read-only access to pipelines and data |

### Data Security
- Connector credentials stored encrypted in JSONB
- Database-level access controls
- SQL injection prevention through parameterized queries
- Multi-statement protection (single query per execution)

### Production Checklist
- [ ] Change default credentials
- [ ] Set strong `SECRET_KEY_BASE`
- [ ] Use environment variables for all secrets
- [ ] Enable HTTPS/SSL
- [ ] Configure database backups
- [ ] Set up monitoring and alerting
- [ ] Review and restrict network access
- [ ] Enable Rails production mode settings

## 🧪 Testing

Run the test suite:

```bash
# All tests
bin/rails test

# Specific test file
bin/rails test test/models/pipeline_test.rb

# With coverage
COVERAGE=true bin/rails test

# System tests (browser-based)
bin/rails test:system
```

**Current Test Status:**
- ✅ 226 tests
- ✅ 556 assertions  
- ✅ 0 failures
- ✅ 0 errors
- ℹ️ 6 skipped (complex stubbing tests marked for refactoring)

Test coverage includes:
- **Models**: Validations, associations, scopes, business logic
- **Controllers**: Authentication, authorization, CRUD operations
- **Jobs**: Pipeline execution, error handling
- **Services**: Pipeline execution service, connector adapters
- **Integration**: End-to-end pipeline creation and execution flows

## 📊 Database Schema

### Core Tables

**pipelines**
- Stores pipeline configuration
- Multiple source connectors via join table
- Optional destination connector

**pipeline_sources** (Join Table)
- Links pipelines to source connectors
- Supports multiple sources per pipeline

**pipeline_runs**
- Execution history
- Status tracking, logs, metrics

**connectors**
- Data source/destination definitions
- JSONB configuration storage
- Connection status tracking

**datasets**
- Available tables/views in connectors
- Schema metadata
- Row counts and status

**users**
- Authentication credentials
- Role-based permissions

### Relationships

```
pipelines
  ├── has_many :pipeline_sources
  ├── has_many :source_connectors (through: pipeline_sources)
  ├── belongs_to :destination_connector (optional)
  └── has_many :pipeline_runs

connectors
  ├── has_many :pipeline_sources
  ├── has_many :pipelines (through: pipeline_sources)
  ├── has_many :datasets
  └── has_many :destination_pipelines

pipeline_runs
  └── belongs_to :pipeline
```

## 🔌 Extending Alice

### Adding a New Connector Type

1. **Create the adapter**

```ruby
# app/services/connector_adapters/my_connector_adapter.rb
module ConnectorAdapters
  class MyConnectorAdapter
    def initialize(connector)
      @connector = connector
      @config = connector.config.with_indifferent_access
    end

    def read_data
      # Return array of hashes
      # [{ "column1" => "value1", "column2" => "value2" }]
    end

    def write_data(table_name:, data:, write_disposition: :append)
      # Write data to destination
      # Return { rows_affected: count, message: "Success" }
    end

    def test_connection
      # Test connection and return true/false
    end

    def fetch_schema
      # Return array of column definitions
      # [{ name: "column1", type: "VARCHAR" }]
    end
  end
end
```

2. **Update connector model**

```ruby
# In app/models/connector.rb
VALID_TYPES = %w[snowflake csv duckdb my_connector].freeze
```

3. **Add configuration validator**

```ruby
def validate_my_connector_config
  required_keys = %w[host port database username password]
  validate_required_config_keys(required_keys)
end
```

4. **Update PipelineExecutionService**

```ruby
def get_adapter(connector)
  case connector.connector_type
  when 'my_connector'
    ConnectorAdapters::MyConnectorAdapter.new(connector)
  # ... other types
  end
end
```

### Adding Custom Validations

Add custom SQL validations in the Pipeline model:

```ruby
# app/models/pipeline.rb
def validate_sql_syntax
  return if transformation_sql.blank?
  
  # Add your custom validation logic
  if transformation_sql.match?(/DROP\s+TABLE/i)
    errors.add(:transformation_sql, "DROP TABLE statements are not allowed")
  end
end
```

## 📦 Deployment

### Dokku Deployment (Recommended)

Alice is designed for deployment on Dokku with PostgreSQL:

```bash
# On Dokku server
dokku apps:create alice

# Create and link PostgreSQL (used for both data and background jobs)
dokku postgres:create alice-db
dokku postgres:link alice-db alice

# Set environment variables
dokku config:set alice \
  RAILS_ENV=production \
  RAILS_SERVE_STATIC_FILES=true \
  RAILS_LOG_TO_STDOUT=true \
  JOB_CONCURRENCY=2 \
  SECRET_KEY_BASE=$(openssl rand -hex 64)

# Scale worker processes (Procfile will be used automatically)
dokku ps:scale alice web=1 worker=1

# Deploy
git remote add dokku dokku@your-server:alice
git push dokku main

# Run migrations (includes Solid Queue tables)
dokku run alice bin/rails db:migrate

# Monitor background jobs
# Check solid_queue_* tables in PostgreSQL or view Rails logs
```

### Docker Deployment

```dockerfile
# Dockerfile included in repository
docker build -t alice .
docker run -p 3000:3000 \
  -e DATABASE_URL=postgresql://user:pass@host/db \
  -e SECRET_KEY_BASE=your_secret \
  alice
```

### Environment Variables (Production)

Required:
- `DATABASE_URL` - PostgreSQL connection (used for both data and job queue)
- `SECRET_KEY_BASE` - Rails secret key
- `RAILS_ENV=production`
- `RAILS_SERVE_STATIC_FILES=true` (if not using CDN)
- `RAILS_LOG_TO_STDOUT=true` (for log aggregation)

Optional:
- `RAILS_MAX_THREADS` - Thread pool size (default: 5)
- `WEB_CONCURRENCY` - Number of Puma workers (default: 2)
- `JOB_CONCURRENCY` - Number of Solid Queue worker processes (default: 2)
- `RAILS_FORCE_SSL=true` - Force HTTPS

### Background Job Processing

Alice uses **Solid Queue** (Rails 8's default) for asynchronous pipeline execution:

**Features:**
- Database-backed job queue (no Redis required)
- Non-blocking pipeline runs
- Automatic retry for failed jobs (up to 3 attempts)
- Built-in with Rails 8
- Configurable concurrency and polling
- Queue-based priority management

**Procfile Configuration:**
```
web: bundle exec puma -C config/puma.rb
worker: bundle exec rake solid_queue:start
```

**Configuration:**
Edit `config/queue.yml` to adjust:
- Thread count per worker
- Number of worker processes
- Polling intervals
- Batch sizes

**Scaling Workers:**
```bash
# Dokku - scale worker processes
dokku ps:scale alice worker=2

# Or set JOB_CONCURRENCY for processes per worker
dokku config:set alice JOB_CONCURRENCY=3
```

**Monitoring:**
- Check Rails logs for job execution details
- Query `solid_queue_jobs` table in PostgreSQL:
  ```sql
  SELECT queue_name, status, COUNT(*) 
  FROM solid_queue_jobs 
  GROUP BY queue_name, status;
  ```
- View failed jobs in `solid_queue_failed_executions` table
- Monitor job processing times and queue depths

## 🛠️ Maintenance

### Database Backups

```bash
# Automated daily backups
dokku postgres:backup alice-db backup-schedule "0 2 * * *"

# Manual backup
dokku postgres:backup alice-db backup-name
```

### Monitoring

Key metrics to monitor:
- Pipeline success rates
- Execution times
- Failed runs
- Connector connection status
- Database connection pool usage
- Memory usage (DuckDB can be memory-intensive)

### Logs

```bash
# View application logs
dokku logs alice -t

# View specific pipeline run logs
# Available in UI under Pipeline → Runs → View Logs
```

## 🤝 Contributing

### Development Workflow

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes
4. Run tests: `bin/rails test`
5. Run linters: `bin/rails rubocop` (if configured)
6. Commit your changes: `git commit -m 'Add amazing feature'`
7. Push to the branch: `git push origin feature/amazing-feature`
8. Open a Pull Request

### Code Style

- Follow Ruby community style guide
- Use Rubocop for linting (if configured)
- Write meaningful commit messages
- Add tests for new features
- Update documentation as needed

## 📄 License

This project is proprietary software. All rights reserved.

## 🙏 Acknowledgments

Built with:
- [Ruby on Rails](https://rubyonrails.org/) - Web framework
- [DuckDB](https://duckdb.org/) - In-process analytical database
- [Tailwind CSS](https://tailwindcss.com/) - Utility-first CSS
- [Stimulus](https://stimulus.hotwired.dev/) - JavaScript framework
- [PostgreSQL](https://www.postgresql.org/) - Primary database
- [Raleway](https://fonts.google.com/specimen/Raleway) - Typography

## 📞 Support

For issues, questions, or feature requests:
- Open an issue in the repository
- Contact the development team
- Check documentation at `/docs` (if available)

---

**Alice** - Making data pipelines simple and elegant.

Version 0.1.0 (MVP) | © 2025 Alice Data Systems
