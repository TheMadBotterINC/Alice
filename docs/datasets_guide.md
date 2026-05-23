# Datasets in Alice

## What are Datasets?

**Datasets** are registered tables from your database connectors that can be used as sources in Alice pipelines. They serve as a bridge between your database connectors and your data pipelines.

Think of Datasets as "bookmarks" for specific tables in your databases - they give Alice the exact information needed to query that table.

## Why Datasets?

### Database Connectors Need Specific Tables

Database connectors (Snowflake, PostgreSQL, DuckDB) connect to an entire database, which may contain:
- Multiple schemas
- Hundreds or thousands of tables
- Various views and materialized views

When you run a pipeline, Alice needs to know **exactly which table** to query. Datasets provide:
- **Table name**: The specific table to read from
- **Schema name**: Which schema contains the table
- **Column metadata**: Column names and data types
- **Source connector**: Which database connection to use

### File Connectors Are Different

File connectors (CSV, Excel) work differently:
- Each connector points to a specific file
- The file has a clear structure (rows and columns)
- No ambiguity about what to read

That's why file connectors can be used directly in pipelines without creating Datasets (though you can create Datasets from files for better organization).

## Creating Datasets

### From Database Connectors (Required)

**Step 1: Navigate to Your Connector**
1. Go to **Connectors** in the main menu
2. Find and click on your database connector (e.g., "Production Snowflake")

**Step 2: Browse Tables**
1. Click the **Browse Tables** button
2. You'll see all schemas and tables in the database
3. Expand schemas to view their tables

**Step 3: Create Dataset**
1. Find the table you want to use
2. Click **Create Dataset** next to the table name
3. Fill in the Dataset form:
   - **Name**: A descriptive name (e.g., "Customer Orders")
   - **Description**: Optional details about the dataset
   - The schema and table name are pre-filled
4. Click **Create Dataset**

**Step 4: Use in Pipelines**
- The Dataset now appears as a data source in:
  - Pipeline source selectors
  - Visual Query Builder data sources
  - Anywhere you need to select data sources

### From File Connectors (Optional)

You can optionally create Datasets from file connectors for:
- Better organization and naming
- Easier reuse across multiple pipelines
- Consistent metadata handling

The process is similar to database connectors, but file connectors can also be used directly without creating Datasets.

## Using Datasets in Pipelines

### SQL-Based Pipelines

When you select a Dataset as a source in a SQL pipeline, you reference it in your SQL by its sanitized name:

```sql
-- Dataset named "Customer Orders" becomes table reference:
SELECT 
  customer_id,
  order_date,
  total_amount
FROM customer_orders
WHERE order_date >= CURRENT_DATE - 30
```

The Dataset name is automatically sanitized to be a valid SQL identifier (spaces removed, special characters handled).

### Visual Query Builder

In the Visual Query Builder:
1. Datasets appear in the **Data Sources** sidebar on the left
2. Each Dataset shows its available columns
3. Click or drag columns to build your query
4. Join multiple Datasets by adding table joins

## Common Workflows

### Workflow 1: Querying a Single Snowflake Table

```
1. Create Snowflake connector → "Sales Database"
2. Browse tables → Find "SALES_TRANSACTIONS" table
3. Create Dataset → "Sales Transactions"
4. Create Pipeline → Select "Sales Transactions" as source
5. Write transformation SQL or use Visual Query Builder
6. Run pipeline
```

### Workflow 2: Joining Multiple Tables

```
1. From "Sales Database" connector:
   - Create Dataset → "Sales Transactions"
   - Create Dataset → "Customers"
   - Create Dataset → "Products"
2. Create Pipeline with multiple sources:
   - Add all three Datasets as sources
3. Write SQL joining the tables:
   SELECT 
     t.transaction_id,
     c.customer_name,
     p.product_name,
     t.quantity,
     t.total_amount
   FROM sales_transactions t
   JOIN customers c ON t.customer_id = c.id
   JOIN products p ON t.product_id = p.id
```

### Workflow 3: Different Schemas

```
1. From "Data Warehouse" connector:
   - Schema: PRODUCTION → Create Dataset → "Live Orders"
   - Schema: STAGING → Create Dataset → "Staging Orders"
   - Schema: ANALYTICS → Create Dataset → "Order Stats"
2. Use appropriate Dataset based on environment/purpose
```

## Dataset Management

### Viewing Datasets

- Navigate to **Datasets** in the main menu
- See all registered Datasets
- View schema information and source connectors
- Check which pipelines use each Dataset

### Updating Datasets

If the underlying table structure changes:
1. Go to the Dataset page
2. Click **Refresh Schema**
3. Alice will fetch the latest column information
4. Pipelines using this Dataset may need updates if columns changed

### Deleting Datasets

⚠️ **Warning**: Deleting a Dataset will affect any pipelines using it.

Before deleting:
1. Check which pipelines use the Dataset
2. Update or remove those pipelines first
3. Then delete the Dataset

## Error Messages

### "Cannot use Snowflake connector directly as a source"

**Problem**: You tried to use a database connector directly in a pipeline.

**Solution**: 
1. Go to Connectors → [Your Connector] → Browse Tables
2. Find the table you want to use
3. Click "Create Dataset"
4. Edit your pipeline to use the Dataset instead of the connector

### "Dataset not found"

**Problem**: A Dataset was deleted but pipelines still reference it.

**Solution**:
1. Create a new Dataset for the same table
2. Update affected pipelines to use the new Dataset
3. Or remove the Dataset reference from the pipeline

## Best Practices

### Naming Datasets

Use clear, descriptive names that indicate:
- **What**: The data content (e.g., "Customer Orders")
- **Where**: The source if you have multiple databases (e.g., "Prod Customer Orders")
- **When**: If time-specific (e.g., "2024 Sales Archive")

**Good Examples**:
- "Production Customer Transactions"
- "Analytics Aggregated Daily Sales"
- "Staging User Events"

**Avoid**:
- Generic names like "Data" or "Table1"
- SQL keywords as names
- Special characters that need escaping

### Organization

Create Datasets strategically:
- **One Dataset per commonly used table**: Don't create Datasets for every table, only ones you actually use
- **Group by purpose**: Use naming conventions to group related Datasets
- **Document in descriptions**: Add helpful context in the Dataset description field

### Performance

Datasets themselves don't affect query performance, but:
- **Create indexes** on source tables for frequently filtered/joined columns
- **Use appropriate schemas**: Development vs production data
- **Consider materialized views**: For complex pre-aggregations

## Frequently Asked Questions

**Q: Do I need to create a Dataset for every table?**
A: No, only create Datasets for tables you plan to use in pipelines.

**Q: Can one table have multiple Datasets?**
A: Yes! You might create different Datasets for the same table with different names or descriptions for different purposes.

**Q: Do Datasets copy data?**
A: No, Datasets are just metadata. They point to the original table - no data is copied.

**Q: Can I use the same Dataset in multiple pipelines?**
A: Yes! That's one of the benefits of Datasets - create once, use many times.

**Q: What happens if the source table is dropped?**
A: The Dataset will still exist but pipelines using it will fail. You'll need to delete the Dataset or update it to point to a different table.

**Q: Can I create Datasets via API?**
A: Currently, Datasets must be created through the UI. API support may be added in the future.

**Q: Do Datasets work with views as well as tables?**
A: Yes! Datasets can reference database views, materialized views, and tables - anything that can be queried with SELECT.

## See Also

- [Visual Query Builder Guide](visual_query_builder_guide.md) - Using Datasets in the visual builder
- [File Handling Guide](file_handling_guide.md) - Understanding file connectors vs Datasets
- [README](../README.md) - General Alice documentation
