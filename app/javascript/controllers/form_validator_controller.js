import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "sqlField", "errorContainer"]
  static outlets = ["sql-highlighter"]
  
  connect() {
    console.log('Form Validator connected')
  }
  
  validateAndSubmit(event) {
    // Prevent default form submission
    event.preventDefault()
    
    // Clear any previous errors
    this.clearErrors()
    
    // If there's no SQL field, skip SQL validation (e.g., for file output only pipelines)
    if (!this.hasSqlFieldTarget) {
      console.log('No SQL field found, skipping SQL validation')
      this.formTarget.submit()
      return
    }
    
    // Get the SQL field value
    const sqlValue = this.sqlFieldTarget.value.trim()
    
    // Validate SQL if there's a SQL highlighter outlet
    if (this.hasSqlHighlighterOutlet) {
      const validation = this.sqlHighlighterOutlet.validateSQL(sqlValue)
      
      if (!validation.valid) {
        // Show errors
        this.displayErrors(validation.errors)
        
        // Scroll to the SQL field
        this.sqlFieldTarget.scrollIntoView({ behavior: 'smooth', block: 'center' })
        
        // Focus on the SQL field
        this.sqlFieldTarget.focus()
        
        return false
      }
    } else {
      // Fallback: basic validation if no SQL highlighter outlet
      if (sqlValue.length === 0) {
        this.displayErrors(['SQL query cannot be empty'])
        return false
      }
      
      // Basic syntax check
      const errors = this.basicSQLValidation(sqlValue)
      if (errors.length > 0) {
        this.displayErrors(errors)
        this.sqlFieldTarget.scrollIntoView({ behavior: 'smooth', block: 'center' })
        this.sqlFieldTarget.focus()
        return false
      }
    }
    
    // If validation passed, submit the form
    console.log('Validation passed, submitting form')
    this.formTarget.submit()
  }
  
  basicSQLValidation(sql) {
    const errors = []
    const trimmedSQL = sql.trim().toUpperCase()
    
    // Check for valid SQL statement start
    if (!trimmedSQL.match(/^(SELECT|WITH|CREATE|INSERT|UPDATE|DELETE)/)) {
      errors.push("SQL must start with a valid statement (SELECT, WITH, CREATE, etc.)")
    }
    
    // Check for balanced parentheses
    const openParens = (sql.match(/\(/g) || []).length
    const closeParens = (sql.match(/\)/g) || []).length
    if (openParens !== closeParens) {
      errors.push(`Unbalanced parentheses: ${openParens} opening, ${closeParens} closing`)
    }
    
    // Check for balanced quotes
    const singleQuotes = (sql.match(/(?<!\\)'/g) || []).length
    if (singleQuotes % 2 !== 0) {
      errors.push("Unbalanced single quotes")
    }
    
    return errors
  }
  
  displayErrors(errors) {
    if (!this.hasErrorContainerTarget) {
      // Create error container if it doesn't exist
      const errorDiv = document.createElement('div')
      errorDiv.className = 'rounded-md bg-red-50 p-4 mt-2'
      errorDiv.setAttribute('data-form-validator-target', 'errorContainer')
      
      const errorHTML = `
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-red-800">SQL Validation Error</h3>
            <div class="mt-2 text-sm text-red-700">
              <ul class="list-disc pl-5 space-y-1">
                ${errors.map(error => `<li>${this.escapeHtml(error)}</li>`).join('')}
              </ul>
            </div>
          </div>
        </div>
      `
      
      errorDiv.innerHTML = errorHTML
      
      // Insert after SQL field
      this.sqlFieldTarget.parentElement.appendChild(errorDiv)
    } else {
      // Update existing error container
      const errorList = this.errorContainerTarget.querySelector('ul')
      if (errorList) {
        errorList.innerHTML = errors.map(error => `<li>${this.escapeHtml(error)}</li>`).join('')
      }
      this.errorContainerTarget.classList.remove('hidden')
    }
  }
  
  clearErrors() {
    if (this.hasErrorContainerTarget) {
      this.errorContainerTarget.remove()
    }
  }
  
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
