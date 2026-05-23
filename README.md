<div align="center">
  <img src="alice-logo.svg" alt="Alice Logo" width="200" />
  <h1>🐰 Alice</h1>
  <p><strong>A modern, open-source data pipeline platform for building, scheduling, and monitoring data transformations.</strong></p>
  <p>Alice makes it simple to connect multiple data sources, transform data using SQL or a visual query builder, and deliver results to your data warehouse—all without writing complex ETL code.</p>
</div>

---

## ✨ Features

### 🔌 **Flexible Connectors**
- **Snowflake** - Cloud data warehouse integration
- **PostgreSQL** - Traditional relational database support
- **DuckDB** - Fast in-process analytics engine
- **File Formats** - CSV, TSV, Excel (.xlsx) support
- **File Upload** - Upload files at pipeline runtime

### 🎨 **Visual Query Builder**
- Drag-and-drop interface for building transformations
- No SQL required (but SQL mode available for power users)
- Column selection, filtering, aggregation, and joins
- Real-time SQL preview as you build

### 🔄 **Pipeline Management**
- Multi-source data merging and transformations
- Cron-based scheduling for automated runs
- Pipeline templates for reusability
- Run history and monitoring
- Success rate tracking

### 🗄️ **Dataset System**
- Create reusable datasets from any connector
- Reference datasets across multiple pipelines
- Automatic schema detection
- SQL query support for dataset definitions

### 🛡️ **Production Ready**
- Role-based access control (Admin/Viewer)
- Background job processing with Solid Queue
- DuckDB-powered transformation engine
- Write dispositions: Append, Truncate & Load, Merge/Upsert
- Row limit controls for development

---

## 🚀 Quick Start

### Prerequisites

- Ruby 3.4.7+ (managed via `mise` or `rbenv`)
- PostgreSQL 16+
- Node.js 18+ and Yarn
- Redis (for background jobs)

### Installation

```bash
# Clone the repository
git clone https://github.com/THEMADBOTTERINC/alice.git
cd alice

# Install dependencies
bundle install
yarn install

# Setup database
bin/rails db:setup

# Start the server
bin/dev
```

Visit `http://localhost:3000` and log in with:
- **Email:** `admin@alice.example`
- **Password:** `password123`

---

## 📖 Documentation

### Creating Your First Pipeline

1. **Create Connectors**
   - Navigate to **Connectors** → **New Connector**
   - Choose your data source type (Snowflake, PostgreSQL, etc.)
   - Configure connection details and test

2. **Create a Dataset** (Optional)
   - Go to **Datasets** → **New Dataset**
   - Select a connector and define your source query
   - Save for reuse across multiple pipelines

3. **Build a Pipeline**
   - Navigate to **Pipelines** → **New Pipeline**
   - Select source(s): connectors or datasets
   - Choose transformation mode:
     - **Visual Mode**: Drag-and-drop query builder
     - **SQL Mode**: Write custom SQL transformations
   - Configure destination (optional)
   - Set schedule (optional)
   - Save and run!

### Visual Query Builder

The visual query builder lets you:
- **Select Columns**: Choose which columns to include
- **Filter Data**: Add WHERE conditions with intuitive UI
- **Aggregate**: SUM, AVG, COUNT, MIN, MAX with GROUP BY
- **Join Sources**: Combine multiple datasets with visual join builder
- **Preview**: See generated SQL in real-time

### Scheduling

Pipelines support cron-based scheduling:
```
0 2 * * *     # Daily at 2 AM
0 */6 * * *   # Every 6 hours
0 9 * * 1     # Every Monday at 9 AM
```

### Write Dispositions

Control how data is written to destinations:
- **Append**: Add new rows to existing data
- **Truncate & Load**: Replace all data
- **Merge**: Upsert based on merge key

---

## 🏗️ Architecture

Alice is built on modern, production-ready technologies:

- **Backend**: Ruby on Rails 8.0
- **Frontend**: Hotwire (Turbo + Stimulus)
- **Styling**: Tailwind CSS
- **Transformation Engine**: DuckDB
- **Primary Database**: PostgreSQL
- **Background Jobs**: Solid Queue
- **Asset Pipeline**: Propshaft

### Why DuckDB?

DuckDB serves as Alice's transformation engine, providing:
- Fast in-process analytics
- SQL compatibility
- Excellent CSV/Parquet support
- Low memory footprint
- Zero server management

---

## 🎯 Use Cases

### Data Integration
Consolidate data from multiple sources into your data warehouse.

### ETL Pipelines
Extract, transform, and load data on a schedule without complex infrastructure.

### Analytics Preparation
Prepare datasets for BI tools and analytics platforms.

### Data Quality Monitoring
Run scheduled pipelines to validate data quality across sources.

---

## 🧪 Demo Data

Alice ships with synthetic MRO (Maintenance, Repair, and Operations) demo data:

- **Equipment Master** - 100 asset records
- **Work Orders** - 1,800 maintenance work orders
- **Parts Inventory** - 900 parts records
- **Demo Pipelines** - Pre-configured examples

Perfect for exploring Alice's features without setting up real data sources!

---

## 🔒 Security

- User authentication with secure password hashing (bcrypt)
- Role-based access control
- Encrypted database credentials
- CSRF protection
- Secure session management

For production deployment:
- Use environment variables for secrets
- Enable SSL/TLS
- Set `SECRET_KEY_BASE` appropriately
- Configure secure Redis connection

---

## 🤝 Contributing

We welcome contributions! Here's how you can help:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Commit your changes**: `git commit -m 'Add amazing feature'`
4. **Push to the branch**: `git push origin feature/amazing-feature`
5. **Open a Pull Request**

### Development Setup

```bash
# Run tests
bin/rails test

# Run linter (if configured)
bundle exec rubocop

# Start development server
bin/dev
```

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and development process.

---

## 📋 Roadmap

- [ ] REST API for pipeline management
- [ ] More connectors (MySQL, SQL Server, BigQuery)
- [ ] Data lineage visualization
- [ ] Custom transformation functions
- [ ] Pipeline orchestration with dependencies
- [ ] Alerting and notifications
- [ ] dbt integration
- [ ] Incremental refresh strategies

---

## 📄 License

This project is licensed under the **Apache License 2.0** - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

Alice stands on the shoulders of giants:

- **Ruby on Rails** - Web application framework
- **DuckDB** - In-process SQL OLAP database
- **Hotwire** - HTML-over-the-wire framework
- **Tailwind CSS** - Utility-first CSS framework

---

## 💬 Community & Support

- **Issues**: [GitHub Issues](https://github.com/THEMADBOTTERINC/alice/issues)
- **Discussions**: [GitHub Discussions](https://github.com/THEMADBOTTERINC/alice/discussions)
- **Documentation**: [Wiki](https://github.com/THEMADBOTTERINC/alice/wiki)

---

## 🌟 Star History

If Alice helps you build better data pipelines, please consider giving it a star! ⭐

---

<div align="center">

**Built with ❤️ for the data community**

[Report Bug](https://github.com/YOUR_USERNAME/alice/issues) · [Request Feature](https://github.com/YOUR_USERNAME/alice/issues) · [Documentation](https://github.com/YOUR_USERNAME/alice/wiki)

</div>
