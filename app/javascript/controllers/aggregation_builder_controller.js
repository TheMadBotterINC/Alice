import { Controller } from "@hotwired/stimulus"

// Aggregation Builder Controller
// Manages aggregate functions (SUM, AVG, COUNT, etc.)
export default class extends Controller {
  static targets = ["container"]

  connect() {
    console.log("Aggregation Builder connected")
  }

  // This will be called by the parent visual query builder
  renderAggregations(columns) {
    if (!this.hasContainerTarget) return

    const container = this.containerTarget
    const aggregatedColumns = columns.filter(col => col.type === "aggregate")

    if (aggregatedColumns.length === 0) {
      container.innerHTML = `
        <div class="text-sm text-gray-500 italic text-center py-2">
          No aggregations. Add aggregate functions to columns.
        </div>
      `
      return
    }

    container.innerHTML = ""
    aggregatedColumns.forEach((col, index) => {
      const colEl = this.createAggregationElement(col, index)
      container.appendChild(colEl)
    })
  }

  createAggregationElement(column, index) {
    const div = document.createElement("div")
    div.className = "bg-purple-50 border border-purple-200 rounded-md p-3 flex items-center justify-between"
    
    const functionLabel = this.getFunctionLabel(column.function)
    
    div.innerHTML = `
      <div class="flex-1">
        <span class="inline-flex items-center px-2 py-1 rounded text-xs font-semibold bg-purple-600 text-white mr-2">
          ${functionLabel}
        </span>
        <span class="font-mono text-sm text-gray-900">${column.column.source}.${column.column.name}</span>
        ${column.alias ? `<span class="text-xs text-gray-500 ml-2">→ ${column.alias}</span>` : ''}
      </div>
    `
    
    return div
  }

  getFunctionLabel(func) {
    const labels = {
      'SUM': '∑ SUM',
      'AVG': '≈ AVG',
      'COUNT': '# COUNT',
      'MIN': '↓ MIN',
      'MAX': '↑ MAX',
      'COUNT_DISTINCT': '⊕ COUNT DISTINCT'
    }
    return labels[func] || func
  }
}
