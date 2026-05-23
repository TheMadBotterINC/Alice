import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["textarea", "highlighted", "error"]
  static values = {
    validateOnChange: { type: Boolean, default: false }
  }
  
  connect() {
    console.log('SQL Highlighter connected')
    this.setupHighlighting()
  }
  
  setupHighlighting() {
    // Create highlighted div if it doesn't exist
    if (!this.hasHighlightedTarget) {
      const highlightedDiv = document.createElement("div")
      highlightedDiv.dataset.sqlHighlighterTarget = "highlighted"
      highlightedDiv.className = "sql-highlighted"
      this.textareaTarget.parentNode.insertBefore(highlightedDiv, this.textareaTarget)
    }
    
    // Initial highlight
    this.highlight()
    
    // Add event listeners
    this.textareaTarget.addEventListener("input", () => this.highlight())
    this.textareaTarget.addEventListener("scroll", () => this.syncScroll())
  }
  
  highlight() {
    const sql = this.textareaTarget.value
    console.log('Highlighting SQL:', sql.substring(0, 50))
    const highlighted = this.highlightSQL(sql)
    console.log('Highlighted HTML:', highlighted.substring(0, 100))
    this.highlightedTarget.innerHTML = highlighted
    
    // Optionally validate on change
    if (this.validateOnChangeValue && sql.trim().length > 0) {
      this.validateSQL(sql)
    }
  }
  
  syncScroll() {
    this.highlightedTarget.scrollTop = this.textareaTarget.scrollTop
    this.highlightedTarget.scrollLeft = this.textareaTarget.scrollLeft
  }
  
  highlightSQL(sql) {
    if (!sql) return ''
    
    // Create tokens array to store all replacements
    const tokens = []
    let text = sql
    
    // Extract strings first (before escaping)
    text = text.replace(/('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*")/g, (match) => {
      tokens.push({ type: 'string', content: match })
      return `\x00TOKEN_${tokens.length - 1}\x00`
    })
    
    // Extract comments
    text = text.replace(/(--[^\n]*)/g, (match) => {
      tokens.push({ type: 'comment', content: match })
      return `\x00TOKEN_${tokens.length - 1}\x00`
    })
    
    // Now escape HTML
    text = text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
    
    // Highlight SQL Keywords
    const keywords = /\b(SELECT|FROM|WHERE|AND|OR|NOT|IN|BETWEEN|LIKE|IS|NULL|JOIN|LEFT|RIGHT|INNER|OUTER|FULL|ON|GROUP|ORDER|BY|HAVING|LIMIT|OFFSET|UNION|INTERSECT|EXCEPT|AS|DISTINCT|ALL|CASE|WHEN|THEN|ELSE|END|WITH|INSERT|UPDATE|DELETE|CREATE|ALTER|DROP|TABLE|VIEW|INDEX|DATABASE|SCHEMA|PRIMARY|KEY|FOREIGN|REFERENCES|CASCADE|SET|VALUES|INTO|DEFAULT|CHECK|CONSTRAINT|UNIQUE|CURRENT_DATE|CURRENT_TIME|CURRENT_TIMESTAMP)\b/gi
    text = text.replace(keywords, (match) => {
      tokens.push({ type: 'keyword', content: match })
      return `\x00TOKEN_${tokens.length - 1}\x00`
    })
    
    // Highlight SQL Functions
    const functions = /\b(COUNT|SUM|AVG|MIN|MAX|ROUND|CEIL|FLOOR|ABS|POWER|SQRT|CONCAT|SUBSTRING|UPPER|LOWER|TRIM|LTRIM|RTRIM|LENGTH|REPLACE|COALESCE|NULLIF|CAST|CONVERT|DATE|DATETIME|TIMESTAMP|EXTRACT|DATEDIFF|DATEADD|NOW|GETDATE|YEAR|MONTH|DAY|HOUR|MINUTE|SECOND)\b/gi
    text = text.replace(functions, (match) => {
      tokens.push({ type: 'function', content: match })
      return `\x00TOKEN_${tokens.length - 1}\x00`
    })
    
    // Highlight Numbers
    const numbers = /\b(\d+\.?\d*|\.\d+)\b/g
    text = text.replace(numbers, (match) => {
      tokens.push({ type: 'number', content: match })
      return `\x00TOKEN_${tokens.length - 1}\x00`
    })
    
    // Highlight Operators
    const operators = /([=<>!]+|[+\-*\/(),;])/g
    text = text.replace(operators, (match) => {
      tokens.push({ type: 'operator', content: match })
      return `\x00TOKEN_${tokens.length - 1}\x00`
    })
    
    // Now replace all tokens with their HTML
    text = text.replace(/\x00TOKEN_(\d+)\x00/g, (match, index) => {
      const token = tokens[parseInt(index)]
      const escapedContent = token.content
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
      return `<span class="sql-${token.type}">${escapedContent}</span>`
    })
    
    return text + '\n'
  }
  
  // Validate SQL syntax
  validateSQL(sql) {
    if (!sql || sql.trim().length === 0) {
      this.clearError()
      return { valid: true }
    }
    
    const errors = []
    const trimmedSQL = sql.trim().toUpperCase()
    
    // Basic DuckDB SQL validation rules
    
    // 1. Check for SELECT statement (most common in transformations)
    if (!trimmedSQL.match(/^(SELECT|WITH|CREATE|INSERT|UPDATE|DELETE)/)) {
      errors.push("SQL must start with a valid statement (SELECT, WITH, CREATE, etc.)")
    }
    
    // 2. Check for balanced parentheses
    const openParens = (sql.match(/\(/g) || []).length
    const closeParens = (sql.match(/\)/g) || []).length
    if (openParens !== closeParens) {
      errors.push(`Unbalanced parentheses: ${openParens} opening, ${closeParens} closing`)
    }
    
    // 3. Check for balanced quotes
    const singleQuotes = (sql.match(/(?<!\\)'/g) || []).length
    if (singleQuotes % 2 !== 0) {
      errors.push("Unbalanced single quotes")
    }
    
    // 4. Check for common syntax errors
    if (trimmedSQL.match(/SELECT.*FROM\s*$/)) {
      errors.push("Incomplete FROM clause - missing table name")
    }
    
    if (trimmedSQL.match(/WHERE\s*$/)) {
      errors.push("Incomplete WHERE clause - missing condition")
    }
    
    if (trimmedSQL.match(/JOIN\s*$/)) {
      errors.push("Incomplete JOIN clause - missing table name")
    }
    
    // 5. Check for SELECT without FROM (unless it's a constant expression)
    if (trimmedSQL.match(/^SELECT/) && !trimmedSQL.match(/FROM/) && !trimmedSQL.match(/^SELECT\s+\d+/)) {
      // Allow SELECT 1, SELECT CURRENT_DATE, etc.
      if (!trimmedSQL.match(/^SELECT\s+(CURRENT_DATE|CURRENT_TIME|CURRENT_TIMESTAMP|\d+|'[^']*')/)) {
        errors.push("SELECT statement missing FROM clause")
      }
    }
    
    // 6. Check for common keyword typos
    const invalidKeywords = trimmedSQL.match(/\b(SLECT|FORM|WEHRE|GROPU|ORDRE)\b/)
    if (invalidKeywords) {
      errors.push(`Possible typo detected: ${invalidKeywords[0]}`)
    }
    
    // 7. Check for missing commas in SELECT lists
    if (trimmedSQL.match(/SELECT[^FROM]+(\w+)\s+(\w+)\s+FROM/)) {
      const selectPart = trimmedSQL.match(/SELECT([^FROM]+)FROM/)
      if (selectPart && selectPart[1]) {
        const columns = selectPart[1].split(',')
        for (const col of columns) {
          // Check if column has multiple words without AS
          if (col.trim().split(/\s+/).length > 2 && !col.match(/\bAS\b/)) {
            errors.push("Possible missing comma in SELECT list")
            break
          }
        }
      }
    }
    
    // 8. Check for semicolon not at end
    const semicolons = sql.match(/;/g)
    if (semicolons && semicolons.length > 1) {
      errors.push("Multiple semicolons detected - only one statement allowed")
    } else if (semicolons && !sql.trim().endsWith(';')) {
      errors.push("Semicolon must be at the end of the statement")
    }
    
    const result = {
      valid: errors.length === 0,
      errors: errors
    }
    
    if (!result.valid && this.hasErrorTarget) {
      this.displayError(result.errors[0])
    } else if (this.hasErrorTarget) {
      this.clearError()
    }
    
    return result
  }
  
  displayError(message) {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message
      this.errorTarget.classList.remove('hidden')
      this.textareaTarget.classList.add('border-red-500', 'focus:border-red-500', 'focus:ring-red-500')
      this.textareaTarget.classList.remove('border-gray-300', 'focus:border-primary', 'focus:ring-primary')
    }
  }
  
  clearError() {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = ''
      this.errorTarget.classList.add('hidden')
      this.textareaTarget.classList.remove('border-red-500', 'focus:border-red-500', 'focus:ring-red-500')
      this.textareaTarget.classList.add('border-gray-300', 'focus:border-primary', 'focus:ring-primary')
    }
  }
}
