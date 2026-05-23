import { Controller } from "@hotwired/stimulus"

// Join Builder Controller
// Manages visual join configuration between tables
export default class extends Controller {
  static targets = ["container", "addButton"]
  static values = {
    sources: Array
  }

  connect() {
    console.log("Join Builder connected")
    this.joins = []
    this.renderJoins()
  }

  addJoin() {
    // Get tables currently in use from visual query builder
    const usedTables = this.getTablesInUse()
    
    // Smart defaults: suggest a join between used tables
    const suggestedJoin = this.suggestJoin(usedTables)
    
    this.joins.push({
      type: "INNER",
      leftTable: suggestedJoin.leftTable,
      leftColumn: suggestedJoin.leftColumn,
      rightTable: suggestedJoin.rightTable,
      rightColumn: suggestedJoin.rightColumn
    })
    
    // Dispatch joinAdded event to trigger expansion BEFORE rendering
    this.dispatch("joinAdded", { detail: { joins: this.joins } })
    
    // Render after a brief delay to let the expand animation initialize
    requestAnimationFrame(() => {
      this.renderJoins()
      this.dispatch("joinsChanged", { detail: { joins: this.joins } })
    })
  }

  removeJoin(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    this.joins.splice(index, 1)
    this.renderJoins()
    this.dispatch("joinsChanged", { detail: { joins: this.joins } })
  }

  updateJoin(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    const field = event.currentTarget.dataset.field
    const value = event.currentTarget.value

    this.joins[index][field] = value
    this.dispatch("joinsChanged", { detail: { joins: this.joins } })
  }

  renderJoins() {
    if (!this.hasContainerTarget) return

    const container = this.containerTarget
    container.innerHTML = ""

    if (this.joins.length === 0) {
      container.innerHTML = `
        <div class="text-sm text-gray-500 italic text-center py-2">
          No joins configured. Click "Add Join" to connect tables.
        </div>
      `
      return
    }

    this.joins.forEach((join, index) => {
      const joinEl = this.createJoinElement(join, index)
      container.appendChild(joinEl)
    })
  }

  createJoinElement(join, index) {
    const div = document.createElement("div")
    div.className = "bg-gradient-to-r from-blue-50 to-purple-50 border-2 border-blue-200 rounded-lg p-4 space-y-3"
    
    // Get mock tables for dropdowns
    const tables = [
      { name: "work_orders", columns: ["wo_number", "equipment_id", "status", "priority", "assigned_technician", "created_date", "completed_date", "labor_hours", "downtime_hours"] },
      { name: "equipment", columns: ["equipment_id", "equipment_type", "model", "serial_number", "location", "status", "operating_hours"] }
    ]

    const leftTable = tables.find(t => t.name === join.leftTable) || tables[0]
    const rightTable = tables.find(t => t.name === join.rightTable) || tables[0]

    div.innerHTML = `
      <div class="flex items-center justify-between">
        <span class="text-xs font-semibold text-blue-700 uppercase tracking-wide">Join #${index + 1}</span>
        <button type="button"
                data-action="click->join-builder#removeJoin"
                data-index="${index}"
                class="text-red-600 hover:text-red-800 text-xs font-medium">
          ✕ Remove
        </button>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-5 gap-3 items-center">
        <!-- Left Table -->
        <div>
          <label class="block text-xs font-medium text-gray-700 mb-1">Left Table</label>
          <select data-action="change->join-builder#updateJoin"
                  data-index="${index}"
                  data-field="leftTable"
                  class="w-full text-sm rounded border-gray-300 focus:border-blue-500 focus:ring-blue-500">
            ${tables.map(t => `<option value="${t.name}" ${join.leftTable === t.name ? 'selected' : ''}>${t.name}</option>`).join('')}
          </select>
        </div>

        <!-- Left Column -->
        <div>
          <label class="block text-xs font-medium text-gray-700 mb-1">Column</label>
          <select data-action="change->join-builder#updateJoin"
                  data-index="${index}"
                  data-field="leftColumn"
                  class="w-full text-sm rounded border-gray-300 focus:border-blue-500 focus:ring-blue-500">
            <option value="">Select...</option>
            ${leftTable.columns.map(c => `<option value="${c}" ${join.leftColumn === c ? 'selected' : ''}>${c}</option>`).join('')}
          </select>
        </div>

        <!-- Join Type -->
        <div class="text-center">
          <label class="block text-xs font-medium text-gray-700 mb-1">Type</label>
          <select data-action="change->join-builder#updateJoin"
                  data-index="${index}"
                  data-field="type"
                  class="w-full text-sm rounded border-blue-300 bg-blue-50 focus:border-blue-500 focus:ring-blue-500 font-semibold">
            <option value="INNER" ${join.type === 'INNER' ? 'selected' : ''}>⟷ INNER</option>
            <option value="LEFT" ${join.type === 'LEFT' ? 'selected' : ''}>⟵ LEFT</option>
            <option value="RIGHT" ${join.type === 'RIGHT' ? 'selected' : ''}>⟶ RIGHT</option>
            <option value="FULL" ${join.type === 'FULL' ? 'selected' : ''}>⟺ FULL</option>
          </select>
        </div>

        <!-- Right Table -->
        <div>
          <label class="block text-xs font-medium text-gray-700 mb-1">Right Table</label>
          <select data-action="change->join-builder#updateJoin"
                  data-index="${index}"
                  data-field="rightTable"
                  class="w-full text-sm rounded border-gray-300 focus:border-blue-500 focus:ring-blue-500">
            ${tables.map(t => `<option value="${t.name}" ${join.rightTable === t.name ? 'selected' : ''}>${t.name}</option>`).join('')}
          </select>
        </div>

        <!-- Right Column -->
        <div>
          <label class="block text-xs font-medium text-gray-700 mb-1">Column</label>
          <select data-action="change->join-builder#updateJoin"
                  data-index="${index}"
                  data-field="rightColumn"
                  class="w-full text-sm rounded border-gray-300 focus:border-blue-500 focus:ring-blue-500">
            <option value="">Select...</option>
            ${rightTable.columns.map(c => `<option value="${c}" ${join.rightColumn === c ? 'selected' : ''}>${c}</option>`).join('')}
          </select>
        </div>
      </div>

      <div class="text-xs text-center font-mono text-gray-600 bg-white/50 rounded px-2 py-1">
        ${join.leftTable || '...'}.${join.leftColumn || '...'} = ${join.rightTable || '...'}.${join.rightColumn || '...'}
      </div>
    `
    
    return div
  }

  // Get tables that are currently being used in the query
  getTablesInUse() {
    // Access the visual query builder controller to get selected columns
    const vqbController = this.application.getControllerForElementAndIdentifier(
      document.querySelector('[data-controller*="visual-query-builder"]'),
      'visual-query-builder'
    )
    
    if (!vqbController || !vqbController.config) {
      return []
    }
    
    // Extract unique table names from selected columns
    const tables = new Set()
    vqbController.config.columns.forEach(col => {
      if (col.source) {
        tables.add(col.source)
      } else if (col.column && col.column.source) {
        tables.add(col.column.source)
      }
    })
    
    return Array.from(tables)
  }

  // Suggest intelligent join defaults
  suggestJoin(usedTables) {
    const tables = [
      { name: "work_orders", columns: ["wo_number", "equipment_id", "status", "priority", "assigned_technician", "created_date", "completed_date", "labor_hours", "downtime_hours"] },
      { name: "equipment", columns: ["equipment_id", "equipment_type", "model", "serial_number", "location", "status", "operating_hours"] }
    ]
    
    let leftTable = ""
    let rightTable = ""
    let leftColumn = ""
    let rightColumn = ""
    
    if (usedTables.length >= 2) {
      // If we have 2+ tables in use, suggest joining them
      leftTable = usedTables[0]
      rightTable = usedTables[1]
      
      // Try to find matching column names
      const leftTableObj = tables.find(t => t.name === leftTable)
      const rightTableObj = tables.find(t => t.name === rightTable)
      
      if (leftTableObj && rightTableObj) {
        // Look for common columns
        for (const col of leftTableObj.columns) {
          if (rightTableObj.columns.includes(col)) {
            leftColumn = col
            rightColumn = col
            break
          }
        }
        
        // If no exact match, look for columns with "_id" suffix
        if (!leftColumn) {
          const idColumns = leftTableObj.columns.filter(c => c.includes('_id'))
          if (idColumns.length > 0 && rightTableObj.columns.includes(idColumns[0])) {
            leftColumn = idColumns[0]
            rightColumn = idColumns[0]
          }
        }
      }
    } else if (usedTables.length === 1) {
      // If only one table is used, suggest joining with the other available table
      leftTable = usedTables[0]
      const otherTables = tables.filter(t => t.name !== leftTable)
      if (otherTables.length > 0) {
        rightTable = otherTables[0].name
        
        // Try to find matching columns
        const leftTableObj = tables.find(t => t.name === leftTable)
        const rightTableObj = otherTables[0]
        
        if (leftTableObj) {
          for (const col of leftTableObj.columns) {
            if (rightTableObj.columns.includes(col)) {
              leftColumn = col
              rightColumn = col
              break
            }
          }
        }
      }
    } else {
      // No tables in use yet, suggest the first two available
      leftTable = tables[0].name
      rightTable = tables[1].name
      
      // Look for common columns between first two tables
      for (const col of tables[0].columns) {
        if (tables[1].columns.includes(col)) {
          leftColumn = col
          rightColumn = col
          break
        }
      }
    }
    
    return { leftTable, leftColumn, rightTable, rightColumn }
  }
}
