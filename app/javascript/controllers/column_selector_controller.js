import { Controller } from "@hotwired/stimulus"

// Column Selector Controller
// Allows browsing and selecting columns from pipeline sources
export default class extends Controller {
  static targets = ["search", "sourcesList"]

  connect() {
    console.log("Column Selector connected")
    this.renderSources()
  }

  renderSources() {
    // For now, show placeholder sources
    // In Phase 2, we'll fetch actual column metadata from connectors
    this.mockSources = {
      work_orders: [
        { name: "wo_number", type: "VARCHAR" },
        { name: "equipment_id", type: "VARCHAR" },
        { name: "equipment_type", type: "VARCHAR" },
        { name: "status", type: "VARCHAR" },
        { name: "priority", type: "VARCHAR" },
        { name: "assigned_technician", type: "VARCHAR" },
        { name: "created_date", type: "DATE" },
        { name: "completed_date", type: "DATE" },
        { name: "labor_hours", type: "DECIMAL" },
        { name: "downtime_hours", type: "DECIMAL" }
      ],
      equipment: [
        { name: "equipment_id", type: "VARCHAR" },
        { name: "equipment_type", type: "VARCHAR" },
        { name: "model", type: "VARCHAR" },
        { name: "serial_number", type: "VARCHAR" },
        { name: "location", type: "VARCHAR" },
        { name: "status", type: "VARCHAR" },
        { name: "operating_hours", type: "DECIMAL" }
      ]
    }

    if (!this.hasSourcesListTarget) return

    const container = this.sourcesListTarget
    container.innerHTML = ""

    // Convert object to array format for rendering
    Object.keys(this.mockSources).forEach(alias => {
      const source = {
        alias: alias,
        columns: this.mockSources[alias]
      }
      const sourceEl = this.createSourceElement(source)
      container.appendChild(sourceEl)
    })
  }

  createSourceElement(source) {
    const div = document.createElement("div")
    div.className = "mb-4 bg-white rounded-xl p-4 border-2 border-gray-300 shadow-md"
    
    div.innerHTML = `
      <div class="font-bold text-lg text-gray-900 mb-3 pb-2 border-b-2 border-gray-200 flex items-center cursor-pointer hover:text-alice-primary transition-colors"
           data-action="click->column-selector#toggleSource"
           data-source="${source.alias}">
        <svg class="w-5 h-5 mr-2 transform transition-transform" data-icon="chevron" viewBox="0 0 20 20">
          <path fill="currentColor" d="M7.41 8.59L12 13.17l4.59-4.58L18 10l-6 6-6-6 1.41-1.41z"/>
        </svg>
        <span class="inline-flex items-center">
          📋 ${source.alias}
        </span>
        <span class="ml-auto text-xs bg-alice-primary text-white px-3 py-1.5 rounded-full font-bold">
          ${source.columns.length}
        </span>
      </div>
      <div class="space-y-1.5" data-source-columns="${source.alias}">
      </div>
    `
    
    // Create column elements with proper event listeners
    const columnsContainer = div.querySelector(`[data-source-columns="${source.alias}"]`)
    source.columns.forEach(col => {
      const columnEl = this.createColumnElement(source.alias, col)
      columnsContainer.appendChild(columnEl)
    })
    
    return div
  }

  createColumnElement(sourceAlias, column) {
    const typeColors = {
      'VARCHAR': 'bg-green-200 text-green-900',
      'DATE': 'bg-purple-200 text-purple-900',
      'DECIMAL': 'bg-orange-200 text-orange-900',
      'NUMBER': 'bg-orange-200 text-orange-900',
      'INTEGER': 'bg-orange-200 text-orange-900'
    }
    const typeColor = typeColors[column.type] || 'bg-gray-200 text-gray-900'
    
    const div = document.createElement("div")
    div.className = "flex items-center justify-between py-3.5 px-4 rounded-lg bg-white border-2 border-gray-200 hover:border-alice-primary hover:shadow-md cursor-move group transition-all mb-2"
    div.draggable = true
    div.dataset.column = JSON.stringify({ source: sourceAlias, name: column.name, type: column.type })
    div.dataset.sourceAlias = sourceAlias
    div.dataset.columnName = column.name
    
    div.innerHTML = `
      <div class="flex-1 min-w-0 mr-3">
        <span class="text-base font-mono text-gray-900 group-hover:text-alice-primary font-semibold transition-colors break-words">${column.name}</span>
      </div>
      <span class="text-xs px-2.5 py-1 rounded-md font-bold whitespace-nowrap flex-shrink-0 ${typeColor}">${column.type}</span>
    `
    
    // Attach event listeners directly
    div.addEventListener('click', (e) => this.selectColumn(e))
    div.addEventListener('dragstart', (e) => this.handleDragStart(e))
    div.addEventListener('dragend', (e) => this.handleDragEnd(e))
    
    return div
  }

  toggleSource(event) {
    const sourceAlias = event.currentTarget.dataset.source
    const columnsEl = this.element.querySelector(`[data-source-columns="${sourceAlias}"]`)
    const iconEl = event.currentTarget.querySelector('[data-icon="chevron"]')
    
    if (columnsEl.classList.contains("hidden")) {
      columnsEl.classList.remove("hidden")
      iconEl.classList.add("rotate-180")
    } else {
      columnsEl.classList.add("hidden")
      iconEl.classList.remove("rotate-180")
    }
  }

  selectColumn(event) {
    const element = event.currentTarget || event.target
    const columnData = element.dataset.column
    
    console.log("Column selected:", columnData)
    
    // Dispatch event to parent visual query builder
    this.dispatch("columnSelected", {
      detail: { column: columnData },
      bubbles: true
    })
    
    // Highlight as selected
    this.updateColumnHighlight(element, true)
  }
  
  updateColumnHighlight(element, selected) {
    const nameSpan = element.querySelector('div span')
    if (selected) {
      element.classList.remove('bg-white')
      element.classList.add('bg-alice-secondary')
      if (nameSpan) {
        nameSpan.classList.remove('text-gray-900')
        nameSpan.classList.add('text-white')
      }
    } else {
      element.classList.add('bg-white')
      element.classList.remove('bg-alice-secondary')
      if (nameSpan) {
        nameSpan.classList.add('text-gray-900')
        nameSpan.classList.remove('text-white')
      }
    }
  }
  
  refreshSelectedState(selectedColumns) {
    // selectedColumns is an array of {source, name} objects
    const allColumnElements = this.element.querySelectorAll('[draggable="true"]')
    
    allColumnElements.forEach(el => {
      const sourceAlias = el.dataset.sourceAlias
      const columnName = el.dataset.columnName
      
      const isSelected = selectedColumns.some(col => 
        col.source === sourceAlias && col.name === columnName
      )
      
      this.updateColumnHighlight(el, isSelected)
    })
  }

  search(event) {
    const query = event.target.value.toLowerCase()
    
    // Simple search implementation
    const allColumns = this.element.querySelectorAll('[draggable="true"]')
    
    allColumns.forEach(col => {
      const columnName = JSON.parse(col.dataset.column).name.toLowerCase()
      if (columnName.includes(query)) {
        col.classList.remove("hidden")
      } else {
        col.classList.add("hidden")
      }
    })
  }

  handleDragStart(event) {
    const columnData = event.currentTarget.dataset.column
    event.dataTransfer.effectAllowed = 'copy'
    event.dataTransfer.setData('application/json', columnData)
    
    // Add visual feedback
    event.currentTarget.classList.add('opacity-50')
  }

  handleDragEnd(event) {
    // Remove visual feedback
    event.currentTarget.classList.remove('opacity-50')
  }
}
