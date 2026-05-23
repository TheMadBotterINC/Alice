# Visual Query Builder User Guide

## Overview

The Visual Query Builder is a powerful, intuitive interface that allows you to build data transformation pipelines without writing SQL. With a beautiful Metabase-style interface, you can drag and drop columns, define filters, create joins, and see your SQL generated in real-time.

## Getting Started

### Before You Begin: Understanding Data Sources

The Visual Query Builder uses **Datasets** as data sources. Before creating a pipeline:

**For Database Connectors** (Snowflake, PostgreSQL, DuckDB):
1. Go to **Connectors** → Select your connector
2. Click **Browse Tables** to see available tables
3. Click **Create Dataset** for each table you want to query
4. The Dataset will appear as a data source in the Visual Query Builder

**For File Connectors** (CSV, Excel):
- File connectors can be used directly without creating Datasets
- However, Datasets are recommended for reusability

### Creating a New Pipeline

1. Navigate to **Pipelines** in the main menu
2. Click **New Pipeline**
3. Choose **Visual Query Builder** option, or
4. Go directly to `/pipelines/new_visual_builder`

### Editing an Existing Pipeline

1. Open any pipeline
2. Click the **Visual Builder** button to switch to visual mode
3. Or navigate to `/pipelines/:id/visual_builder`

## Interface Layout

The Visual Query Builder interface consists of three main areas:

### Left Sidebar: Data Sources
- Browse available **Datasets** and their columns
- Each Dataset represents a specific table from a connector
- Search for specific columns using the search box
- Click or drag columns to add them to your query
- View quick stats: column count, filter count, join count

**Note**: If you don't see your data source:
- Database connectors require creating a Dataset first (see "Before You Begin" above)
- Go to Connectors → [Your Connector] → Browse Tables → Create Dataset

### Main Content Area
- **Selected Columns**: Columns included in your SELECT statement
- **Table Joins**: Define relationships between tables
- **Filters**: WHERE conditions to filter your data
- **Group By**: Aggregate data by specific columns
- **Sort (Order By)**: Define the order of results

### Top Bar
- Pipeline name and breadcrumbs
- **Save Query** button (for existing pipelines)
- Real-time query statistics

## Building Queries

### Adding Columns

**Method 1: Click to Add**
1. Browse the data sources in the left sidebar
2. Click on any column name
3. The column is automatically added to "Selected Columns"

**Method 2: Drag and Drop**
1. Click and hold on a column name
2. Drag it to the "Selected Columns" area
3. Release to add the column

**Column Options**:
- **Alias**: Click the alias field to give columns custom names
- **Remove**: Click the ❌ button to remove a column
- **Reorder**: Columns appear in your SELECT statement in the order shown

### Creating Filters (WHERE Conditions)

1. Click **Add Filter** in the Filters section
2. Select the column to filter
3. Choose an operator:
   - `=` Equal to
   - `!=` Not equal to
   - `>` Greater than
   - `<` Less than
   - `>=` Greater than or equal
   - `<=` Less than or equal
   - `LIKE` Pattern matching
   - `IN` Match multiple values
   - `IS NULL` / `IS NOT NULL` Check for null values
4. Enter the filter value
5. Click **Remove** to delete a filter

**Multiple Filters**: All filters are combined with AND logic.

### Adding Table Joins

1. Click **Add Join** in the Table Joins section
2. Select the **Join Type**:
   - **INNER JOIN**: Only matching rows from both tables
   - **LEFT JOIN**: All rows from left table, matching from right
   - **RIGHT JOIN**: All rows from right table, matching from left
   - **FULL OUTER JOIN**: All rows from both tables
3. Select the **Right Table** (the table to join)
4. Define the join condition:
   - **Left Column**: Column from your main table
   - **Right Column**: Column from the joined table
5. Click **Remove** to delete a join

### Grouping Data (GROUP BY)

1. Click **Add** in the Group By section
2. Select the column to group by
3. Add aggregate functions to your columns:
   - **COUNT**: Count rows
   - **SUM**: Sum numeric values
   - **AVG**: Calculate average
   - **MIN**: Find minimum value
   - **MAX**: Find maximum value
4. Multiple GROUP BY columns create nested groupings

### Sorting Results (ORDER BY)

1. Click **Add** in the Sort section
2. Select the column to sort by
3. Choose sort direction:
   - **ASC**: Ascending (A-Z, 0-9, oldest-newest)
   - **DESC**: Descending (Z-A, 9-0, newest-oldest)
4. Multiple sort columns are applied in order

### Setting Row Limits

- Enter a number in the **Limit** field to restrict result count
- Leave empty for unlimited results
- Useful for testing or creating "Top N" queries

## SQL Preview

As you build your query visually, the generated SQL appears in the **Generated SQL** section:

- Updates in real-time as you make changes
- Shows the exact SQL that will be executed
- Copy the SQL if you need to use it elsewhere
- Formatted for readability with syntax highlighting

## Saving Your Work

### For Existing Pipelines
1. Make your changes in the visual builder
2. Click **💾 Save Query** in the top right
3. Your changes are saved and the pipeline is updated

### For New Pipelines
1. Fill in the **Pipeline Name** (required)
2. Optionally add a **Description**
3. Build your query using the visual tools
4. The form automatically saves as you build

## Tips and Best Practices

### Performance Tips
1. **Add filters early**: Filtering data reduces the amount processed
2. **Limit columns**: Only select columns you need
3. **Use appropriate joins**: INNER JOINs are typically faster than OUTER JOINs
4. **Test with LIMIT**: Use LIMIT while building to see results faster

### Query Building Workflow
1. Start by selecting your main data source columns
2. Add any necessary joins to bring in related data
3. Define filters to narrow your dataset
4. Add grouping if you need aggregated results
5. Set sorting to order your results
6. Add a limit for testing, remove for production

### Column Organization
- Use aliases to make column names more readable
- Group related columns together
- Remove columns you don't need to keep queries clean

### Filter Best Practices
- Use specific filters to reduce data early
- Combine multiple filters for precise results
- Use IS NULL/IS NOT NULL to handle missing data
- LIKE filters are powerful but can be slow on large datasets

## Common Patterns

### Simple Selection Query
```
1. Select columns from one table
2. Add filters to narrow results
3. Add sorting if needed
```

### Aggregation Query
```
1. Select columns to group by
2. Add aggregate functions (COUNT, SUM, etc.)
3. Add filters (applied before grouping)
4. Use GROUP BY section
5. Sort by aggregated values
```

### Multi-Table Query
```
1. Select columns from primary table
2. Add joins to bring in related tables
3. Select columns from joined tables
4. Add filters across all tables
5. Sort as needed
```

### Top N Query
```
1. Select desired columns
2. Add filters if needed
3. Sort by ranking criteria (DESC for highest first)
4. Set LIMIT to N
```

## Troubleshooting

### Data Source Not Appearing
- **Database connectors require Datasets**: You cannot use Snowflake, PostgreSQL, or DuckDB connectors directly
  - Solution: Go to Connectors → [Your Connector] → Browse Tables → Create Dataset
  - Then refresh the Visual Query Builder to see the new Dataset
- File connectors (CSV/Excel) can be used directly without Datasets

### Column Not Appearing
- Check if the column is hidden by search filters
- Verify the data source is properly configured
- Refresh the page to reload data sources

### SQL Not Generating
- Ensure at least one column is selected
- Check browser console for JavaScript errors
- Try adding a column to trigger regeneration

### Join Not Working
- Verify both tables have the join columns
- Check that column types are compatible
- Ensure join condition is complete

### Query Too Slow
- Add more specific filters
- Reduce the number of columns selected
- Check if indexes exist on filtered/joined columns
- Use LIMIT while testing

## Keyboard Shortcuts

- **Search**: Click the search box in Data Sources (no shortcut needed)
- **Save**: Click Save Query button (or use browser's Cmd/Ctrl+S)

## Getting Help

If you encounter issues:
1. Check the SQL Preview to see what's being generated
2. Review the Query Stats to understand your query complexity
3. Try building a simpler query first, then add complexity
4. Check the Rails logs for backend errors

## Feature Highlights

✨ **Drag and Drop**: Intuitive column selection
📊 **Real-time SQL**: See your query as you build it
🎨 **Beautiful UI**: Clean, modern interface with Alice brand colors
🔍 **Smart Search**: Quickly find columns across all sources
📈 **Query Stats**: Track complexity at a glance
💾 **Auto-save**: Changes saved automatically as you build
