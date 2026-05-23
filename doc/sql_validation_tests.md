# SQL Validation Test Cases

This document provides test cases for the client-side SQL validation in the Pipeline form.

## Valid SQL Examples (Should Pass)

### Basic SELECT
```sql
SELECT * FROM customers
```

### SELECT with WHERE
```sql
SELECT 
  customer_id,
  first_name,
  last_name
FROM customers
WHERE state = 'CA'
```

### JOIN Query
```sql
SELECT 
  o.order_id,
  c.customer_name,
  o.total_amount
FROM orders AS o
LEFT JOIN customers AS c ON o.customer_id = c.id
WHERE o.order_date >= CURRENT_DATE - 7
```

### WITH (CTE) Query
```sql
WITH daily_sales AS (
  SELECT 
    DATE(order_date) as sale_date,
    SUM(amount) as total
  FROM orders
  GROUP BY DATE(order_date)
)
SELECT * FROM daily_sales
WHERE total > 1000
```

### Aggregation Query
```sql
SELECT 
  product_category,
  COUNT(*) as order_count,
  SUM(quantity) as total_units,
  AVG(price) as avg_price
FROM line_items
GROUP BY product_category
HAVING COUNT(*) > 100
ORDER BY total_units DESC
```

## Invalid SQL Examples (Should Fail)

### Missing FROM Clause
```sql
SELECT customer_id, name
```
**Error:** "SELECT statement missing FROM clause"

### Unbalanced Parentheses
```sql
SELECT * FROM orders WHERE (status = 'active' AND total > 100
```
**Error:** "Unbalanced parentheses: 1 opening, 0 closing"

### Unbalanced Single Quotes
```sql
SELECT * FROM customers WHERE name = 'John
```
**Error:** "Unbalanced single quotes"

### Incomplete FROM Clause
```sql
SELECT * FROM
```
**Error:** "Incomplete FROM clause - missing table name"

### Incomplete WHERE Clause
```sql
SELECT * FROM orders WHERE
```
**Error:** "Incomplete WHERE clause - missing condition"

### Incomplete JOIN Clause
```sql
SELECT * FROM orders o LEFT JOIN
```
**Error:** "Incomplete JOIN clause - missing table name"

### Common Typos
```sql
SLECT * FROM customers
```
**Error:** "Possible typo detected: SLECT"

```sql
SELECT * FORM customers
```
**Error:** "Possible typo detected: FORM"

### Invalid Statement Start
```sql
UPDATE customers SET name = 'test'
```
**Note:** UPDATEs are actually allowed in DuckDB transformations

### Multiple Semicolons
```sql
SELECT * FROM orders; SELECT * FROM customers;
```
**Error:** "Multiple semicolons detected - only one statement allowed"

### Semicolon in Middle
```sql
SELECT * FROM orders; WHERE status = 'active'
```
**Error:** "Semicolon must be at the end of the statement"

## Manual Testing Steps

1. **Start the Rails server:**
   ```bash
   rails s
   ```

2. **Navigate to Pipeline Creation:**
   - Go to http://localhost:3000/pipelines/new
   - Or edit an existing pipeline

3. **Test Valid SQL:**
   - Paste one of the valid SQL examples above
   - Click "Save" or "Create Pipeline"
   - Form should submit successfully

4. **Test Invalid SQL:**
   - Paste one of the invalid SQL examples above
   - Click "Save" or "Create Pipeline"
   - Should see red error message appear
   - SQL field should have red border
   - Page should scroll to the SQL field
   - Form should NOT submit

5. **Test Error Clearing:**
   - After seeing an error, fix the SQL
   - Click "Save" again
   - Error should clear and form should submit

## Browser Console Testing

You can also test the validation directly in the browser console:

```javascript
// Get the SQL highlighter controller
const sqlController = Stimulus.controllers.find(c => c.identifier === 'sql-highlighter')

// Test validation
sqlController.validateSQL("SELECT * FROM customers")
// Should return: { valid: true, errors: [] }

sqlController.validateSQL("SELECT * FROM")
// Should return: { valid: false, errors: ["Incomplete FROM clause - missing table name"] }

sqlController.validateSQL("SELECT * customers")
// Should return: { valid: false, errors: ["SELECT statement missing FROM clause"] }
```

## Implementation Notes

### Validation Rules Implemented:

1. **Statement Start:** Must begin with SELECT, WITH, CREATE, INSERT, UPDATE, or DELETE
2. **Balanced Parentheses:** All opening parentheses must have matching closing ones
3. **Balanced Quotes:** Single quotes must be balanced
4. **Incomplete Clauses:** Detects incomplete FROM, WHERE, and JOIN clauses
5. **Missing FROM:** SELECT statements must have a FROM clause (unless selecting constants)
6. **Typo Detection:** Catches common misspellings (SLECT, FORM, WEHRE, GROPU, ORDRE)
7. **Semicolon Usage:** Only one statement allowed, semicolon must be at end if present

### Future Enhancements:

- Add support for validating table names against available sources
- Check for column name typos
- Validate function names
- Support for DuckDB-specific syntax (e.g., COPY, ATTACH)
- Line-by-line error highlighting
- Warning messages (non-blocking) for style issues
