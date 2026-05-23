import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["icon"]
  static values = {
    connectorId: Number,
    schemaName: String,
    tableName: String,
    expanded: Boolean
  }

  connect() {
    this.expandedValue = false
    // Find the next sibling row (the accordion content row)
    this.contentRow = this.element.nextElementSibling
    if (this.contentRow) {
      this.loadingDiv = this.contentRow.querySelector('[data-loading]')
      this.schemaContentDiv = this.contentRow.querySelector('[data-schema-content]')
    }
  }

  toggle(event) {
    // Prevent the row click if clicking on the "Create Dataset" button
    if (event.target.closest('.btn-alice-primary')) {
      return
    }

    if (this.expandedValue) {
      this.collapse()
    } else {
      this.expand()
    }
  }

  expand() {
    this.expandedValue = true
    
    // Show the content row
    if (this.contentRow) {
      this.contentRow.classList.remove("hidden")
    }
    
    // Show loading state
    if (this.loadingDiv) {
      this.loadingDiv.classList.remove("hidden")
    }
    if (this.schemaContentDiv) {
      this.schemaContentDiv.classList.add("hidden")
    }
    
    // Rotate icon
    if (this.hasIconTarget) {
      this.iconTarget.classList.add("rotate-90")
    }

    // Fetch schema if not already loaded
    if (!this.schemaContentDiv || this.schemaContentDiv.dataset.loaded !== "true") {
      this.fetchSchema()
    } else {
      // Already loaded, just show it
      if (this.loadingDiv) {
        this.loadingDiv.classList.add("hidden")
      }
      if (this.schemaContentDiv) {
        this.schemaContentDiv.classList.remove("hidden")
      }
    }
  }

  collapse() {
    this.expandedValue = false
    
    // Hide the content row
    if (this.contentRow) {
      this.contentRow.classList.add("hidden")
    }
    
    // Rotate icon back
    if (this.hasIconTarget) {
      this.iconTarget.classList.remove("rotate-90")
    }
  }

  async fetchSchema() {
    try {
      const url = `/connectors/${this.connectorIdValue}/table_schema?schema_name=${encodeURIComponent(this.schemaNameValue)}&table_name=${encodeURIComponent(this.tableNameValue)}`
      
      const response = await fetch(url, {
        headers: {
          'Accept': 'application/json'
        }
      })

      const data = await response.json()

      if (data.success) {
        this.renderSchema(data.schema)
      } else {
        this.renderError(data.error)
      }
    } catch (error) {
      console.error('Failed to fetch table schema:', error)
      this.renderError(error.message)
    }
  }

  renderSchema(schema) {
    if (this.loadingDiv) {
      this.loadingDiv.classList.add("hidden")
    }

    if (this.schemaContentDiv) {
      const columns = schema.columns
      
      let html = `
        <div class="px-6 py-4 bg-gray-50 border-t">
          <div class="mb-3">
            <h4 class="text-sm font-semibold text-gray-700">Schema: ${schema.schema}.${schema.table}</h4>
            <p class="text-xs text-gray-500 mt-1">${columns.length} columns</p>
          </div>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 text-sm">
              <thead class="bg-gray-100">
                <tr>
                  <th class="px-3 py-2 text-left text-xs font-medium text-gray-600 uppercase">Column</th>
                  <th class="px-3 py-2 text-left text-xs font-medium text-gray-600 uppercase">Type</th>
                  <th class="px-3 py-2 text-left text-xs font-medium text-gray-600 uppercase">Nullable</th>
                  <th class="px-3 py-2 text-left text-xs font-medium text-gray-600 uppercase">Default</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
      `

      columns.forEach(col => {
        let typeDisplay = col.type
        if (col.max_length) {
          typeDisplay += `(${col.max_length})`
        } else if (col.precision && col.scale) {
          typeDisplay += `(${col.precision},${col.scale})`
        } else if (col.precision) {
          typeDisplay += `(${col.precision})`
        }

        html += `
          <tr class="hover:bg-gray-50">
            <td class="px-3 py-2 whitespace-nowrap font-medium text-gray-900">${col.name}</td>
            <td class="px-3 py-2 whitespace-nowrap text-gray-700">${typeDisplay}</td>
            <td class="px-3 py-2 whitespace-nowrap">
              ${col.nullable ? 
                '<span class="text-green-600">✓</span>' : 
                '<span class="text-gray-400">—</span>'
              }
            </td>
            <td class="px-3 py-2 text-gray-600 text-xs">${col.default || '—'}</td>
          </tr>
        `
      })

      html += `
              </tbody>
            </table>
          </div>
        </div>
      `

      this.schemaContentDiv.innerHTML = html
      this.schemaContentDiv.dataset.loaded = "true"
      this.schemaContentDiv.classList.remove("hidden")
    }
  }

  renderError(error) {
    if (this.loadingDiv) {
      this.loadingDiv.classList.add("hidden")
    }

    if (this.schemaContentDiv) {
      this.schemaContentDiv.innerHTML = `
        <div class="px-6 py-4 bg-red-50 border-t">
          <p class="text-sm text-red-800">
            <svg class="inline h-4 w-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
            </svg>
            Failed to load schema: ${error}
          </p>
        </div>
      `
      this.schemaContentDiv.classList.remove("hidden")
    }
  }
}
