import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="connector-table-inputs"
export default class extends Controller {
  static targets = ["tableInputs", "tableSelect"]

  connect() {
    // Load tables for any visible table inputs on page load
    this.tableInputsTargets.forEach(div => {
      if (!div.classList.contains('hidden')) {
        const connectorId = div.dataset.connectorId
        this.loadTablesForConnector(connectorId)
      }
    })
  }

  toggleTableInputs(event) {
    const checkbox = event.target
    const connectorId = checkbox.value
    const isChecked = checkbox.checked
    const connectorType = checkbox.dataset.connectorType
    
    // Only show table inputs for non-file connectors
    const isFileConnector = connectorType && connectorType.startsWith('file_')
    
    if (!isFileConnector) {
      const tableInputsDiv = document.getElementById(`table_inputs_${connectorId}`)
      
      if (tableInputsDiv) {
        if (isChecked) {
          tableInputsDiv.classList.remove('hidden')
          // Load tables when first checked
          this.loadTablesForConnector(connectorId)
        } else {
          tableInputsDiv.classList.add('hidden')
        }
      }
    }
  }
  
  loadTablesForConnector(connectorId) {
    const select = document.getElementById(`table_select_${connectorId}`)
    if (!select) return
    
    // Show loading state
    select.innerHTML = '<option value="">Loading tables...</option>'
    select.disabled = true
    
    // Fetch available tables
    fetch(`/connectors/${connectorId}/available_tables`)
      .then(response => response.json())
      .then(data => {
        if (data.success) {
          this.populateTableOptions(connectorId, data.tables)
        } else {
          select.innerHTML = `<option value="">Error: ${data.error}</option>`
        }
      })
      .catch(error => {
        console.error('Error fetching tables:', error)
        select.innerHTML = '<option value="">Error loading tables</option>'
      })
      .finally(() => {
        select.disabled = false
      })
  }
  
  populateTableOptions(connectorId, tables) {
    const select = document.getElementById(`table_select_${connectorId}`)
    if (!select) return
    
    // Clear existing options
    select.innerHTML = '<option value="">-- Select a table --</option>'
    
    // Add options for each table
    tables.forEach(table => {
      const option = document.createElement('option')
      option.value = JSON.stringify({ schema: table.schema, table: table.table })
      option.textContent = table.display
      select.appendChild(option)
    })
    
    // Add change listener to update hidden fields
    select.addEventListener('change', () => {
      const schemaInput = document.getElementById(`schema_${connectorId}`)
      const tableInput = document.getElementById(`table_${connectorId}`)
      
      if (select.value && select.value !== '') {
        const data = JSON.parse(select.value)
        schemaInput.value = data.schema
        tableInput.value = data.table
      } else {
        schemaInput.value = ''
        tableInput.value = ''
      }
    })
  }
}
