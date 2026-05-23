import { Controller } from "@hotwired/stimulus"

// Main Visual Query Builder controller
// Orchestrates the entire visual builder interface
export default class extends Controller {
  static targets = [
    "modeToggle",
    "visualPanel",
    "sqlPanel",
    "sqlPreview",
    "configInput",
    "sqlInput",
    "modeInput",
    "columnsContainer",
    "filtersContainer",
    "groupByContainer",
    "orderByContainer",
    "joinsContainer",
    "limitInput",
    "advancedSections",
    "advancedBanner",
    "quickStartPanel"
  ]

  static values = {
    pipelineId: Number,
    mode: { type: String, default: "sql" }
  }

  connect() {
    console.log("Visual Query Builder connected")
    this.config = this.loadInitialConfig()
    this.advancedSectionsRevealed = false // Track if we've shown advanced sections
    this.updateView()
    
    // Check if we should show advanced sections on load (if columns exist)
    this.updateAdvancedSectionsVisibility()
    
    // Check if we should show Quick Start panel
    this.updateQuickStartVisibility()
    
    // Refresh column selector highlights after a brief delay to ensure it's loaded
    setTimeout(() => this.refreshColumnSelectorState(), 100)
  }

  loadInitialConfig() {
    // Load existing config from hidden input or create new
    if (this.hasConfigInputTarget && this.configInputTarget.value) {
      try {
        return JSON.parse(this.configInputTarget.value)
      } catch (e) {
        console.error("Failed to parse transformation config:", e)
      }
    }

    // Default empty config
    return {
      version: "1.0",
      sources: [],
      columns: [],
      filters: [],
      joins: [],
      groupBy: [],
      orderBy: [],
      limit: null
    }
  }

  // Handle joins changed event from join-builder
  updateJoins(event) {
    if (event.detail && event.detail.joins) {
      this.config.joins = event.detail.joins
      this.saveConfig()
      this.updateStats()
    }
  }

  // Update join-builder controller from config
  updateJoinBuilderFromConfig() {
    const joinBuilderEl = document.querySelector('[data-controller*="join-builder"]')
    if (!joinBuilderEl) return
    
    const joinBuilder = this.application.getControllerForElementAndIdentifier(joinBuilderEl, 'join-builder')
    if (!joinBuilder) return
    
    // Set joins and re-render
    joinBuilder.joins = this.config.joins || []
    joinBuilder.renderJoins()
    
    // Update stats
    this.updateStats()
  }

  // Switch between visual and SQL modes
  switchMode(event) {
    const newMode = event.currentTarget.dataset.mode
    
    if (newMode === this.modeValue) {
      return // Already in this mode
    }

    // Confirm switch if there are unsaved changes
    if (!this.confirmModeSwitch()) {
      return
    }

    this.modeValue = newMode
    this.updateView()
  }

  confirmModeSwitch() {
    // TODO: Add dirty checking
    return true
  }

  updateView() {
    // Update mode toggle active state
    if (this.hasModeToggleTarget) {
      this.modeToggleTargets.forEach(toggle => {
        const toggleMode = toggle.dataset.mode
        if (toggleMode === this.modeValue) {
          toggle.classList.add("active", "bg-alice-primary", "text-white")
          toggle.classList.remove("bg-gray-100", "text-gray-700")
        } else {
          toggle.classList.remove("active", "bg-alice-primary", "text-white")
          toggle.classList.add("bg-gray-100", "text-gray-700")
        }
      })
    }

    // Show/hide panels
    if (this.hasVisualPanelTarget && this.hasSqlPanelTarget) {
      if (this.modeValue === "visual") {
        this.visualPanelTarget.classList.remove("hidden")
        this.sqlPanelTarget.classList.add("hidden")
      } else {
        this.visualPanelTarget.classList.add("hidden")
        this.sqlPanelTarget.classList.remove("hidden")
      }
    }

// Update hidden mode input
    if (this.hasModeInputTarget) {
      this.modeInputTarget.value = this.modeValue
    }

    // Render all sections
    this.renderColumns()
    this.renderFilters()
    this.renderGroupBy()
    this.renderOrderBy()
    
    // Update SQL preview
    this.updateSqlPreview()
  }

  // Add a column to the query
  addColumn(event) {
    console.log("addColumn called", event.detail)
    const columnData = JSON.parse(event.detail.column)
    
    console.log("Parsed column data:", columnData)
    
    this.config.columns.push({
      type: "source_column",
      source: columnData.source,
      name: columnData.name,
      alias: null
    })

    this.saveConfig()
    this.renderColumns()
    this.updateSqlPreview()
    this.refreshColumnSelectorState()
    this.updateAdvancedSectionsVisibility()
  }

  // Remove a column
  removeColumn(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    this.config.columns.splice(index, 1)
    
    this.saveConfig()
    this.renderColumns()
    this.updateSqlPreview()
    this.refreshColumnSelectorState()
    this.updateAdvancedSectionsVisibility()
  }

  // Add a filter
  addFilter() {
    this.config.filters.push({
      column: { source: "", name: "" },
      operator: "=",
      value: ""
    })

    this.saveConfig()
    this.renderFilters()
  }

  // Remove a filter
  removeFilter(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    this.config.filters.splice(index, 1)
    
    this.saveConfig()
    this.renderFilters()
    this.updateSqlPreview()
  }

  // Render columns list
  renderColumns() {
    if (!this.hasColumnsContainerTarget) return

    const container = this.columnsContainerTarget
    container.innerHTML = ""

    // Set up drop zone
    container.addEventListener('dragover', this.handleDragOver.bind(this))
    container.addEventListener('drop', this.handleDrop.bind(this))

    if (this.config.columns.length === 0) {
      container.innerHTML = `
        <div class="text-base text-gray-600 italic py-8 text-center border-2 border-dashed border-gray-300 rounded-lg bg-gray-50">
          🔘 Drag columns here or click to add
        </div>
      `
      this.updateStats()
      this.updateQuickStartVisibility()
      return
    }

    this.config.columns.forEach((column, index) => {
      const columnEl = this.createColumnElement(column, index)
      container.appendChild(columnEl)
    })
    
    this.updateStats()
    this.updateQuickStartVisibility()
  }

  createColumnElement(column, index) {
    const div = document.createElement("div")
    div.className = "bg-white border-l-4 border-gray-300 rounded-md p-3 hover:border-blue-500 transition-all shadow-sm"
    
    let columnDisplay = ''
    let badgeColor = 'bg-gray-100 text-gray-700'
    let badgeIcon = '📊'
    
    if (column.type === "source_column") {
      columnDisplay = `${column.source}.${column.name}`
      badgeIcon = '📋'
      badgeColor = 'bg-blue-100 text-blue-700'
    } else if (column.type === "aggregate") {
      columnDisplay = `${column.function}(${column.column.source}.${column.column.name})`
      badgeIcon = this.getAggregateIcon(column.function)
      badgeColor = 'bg-purple-100 text-purple-700'
    }

    const smartAlias = column.alias || this.generateSmartAlias(column)
    
    div.innerHTML = `
      <div class="flex items-start justify-between space-x-3">
        <div class="flex-1 min-w-0">
          <div class="flex items-center space-x-2 mb-2">
            <span class="text-xs px-2 py-0.5 rounded font-semibold ${badgeColor}">
              ${badgeIcon} ${column.type === 'aggregate' ? column.function : 'COLUMN'}
            </span>
          </div>
          <div class="font-mono text-sm text-gray-900 break-all">${columnDisplay}</div>
          <div class="mt-2">
            <label class="block text-xs font-medium text-gray-600 mb-1">Alias:</label>
            <input type="text"
                   value="${column.alias || ''}"
                   placeholder="${smartAlias}"
                   data-index="${index}"
                   data-action="blur->visual-query-builder#updateColumnAlias keydown->visual-query-builder#handleAliasKeydown"
                   class="w-full px-2 py-1 text-sm border-2 border-gray-200 rounded focus:border-blue-400 focus:ring-2 focus:ring-blue-100 transition-all font-mono"
                   aria-label="Column alias">
          </div>
          ${column.type === 'source_column' ? `
            <div class="mt-2">
              <button type="button" 
                      data-action="click->visual-query-builder#convertToAggregate"
                      data-index="${index}"
                      class="text-xs text-purple-600 hover:text-purple-800 font-medium">
                🔄 Add Function
              </button>
            </div>
          ` : ''}
        </div>
        <button type="button" 
                data-action="click->visual-query-builder#removeColumn"
                data-index="${index}"
                class="text-red-500 hover:text-red-700 text-lg leading-none">
          ✕
        </button>
      </div>
    `
    
    return div
  }

  getAggregateIcon(func) {
    const icons = {
      'SUM': '∑',
      'AVG': '≈',
      'COUNT': '#',
      'MIN': '↓',
      'MAX': '↑',
      'COUNT_DISTINCT': '⊕'
    }
    return icons[func] || '📊'
  }

  // Render filters list
  renderFilters() {
    if (!this.hasFiltersContainerTarget) return

    const container = this.filtersContainerTarget
    container.innerHTML = ""

    if (this.config.filters.length === 0) {
      container.innerHTML = `
        <div class="text-sm text-gray-500 italic">No filters</div>
      `
      return
    }

    this.config.filters.forEach((filter, index) => {
      const filterEl = this.createFilterElement(filter, index)
      container.appendChild(filterEl)
    })
  }

  createFilterElement(filter, index) {
    const div = document.createElement("div")
    div.className = "bg-gradient-to-r from-yellow-50 to-amber-50 border-2 border-yellow-300 rounded-lg p-4 space-y-3"
    
    const operators = ['=', '!=', '>', '<', '>=', '<=', 'LIKE', 'IN', 'IS NULL', 'IS NOT NULL']
    const columns = this.getAvailableColumns()
    
    div.innerHTML = `
      <div class="flex items-center justify-between">
        <span class="text-xs font-semibold text-yellow-700 uppercase tracking-wide">🔍 Filter #${index + 1}</span>
        <button type="button" 
                data-action="click->visual-query-builder#removeFilter"
                data-index="${index}"
                class="text-red-600 hover:text-red-800 text-xs font-medium">
          ✕ Remove
        </button>
      </div>
      
      <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
        <!-- Column Selection -->
        <div>
          <label class="block text-xs font-medium text-gray-700 mb-1">Column</label>
          <select data-action="change->visual-query-builder#updateFilter"
                  data-index="${index}"
                  data-field="column"
                  class="w-full text-sm rounded border-gray-300 focus:border-yellow-500 focus:ring-yellow-500">
            <option value="">Select column...</option>
            ${columns.map(c => {
              const colValue = JSON.stringify({ source: c.source, name: c.name })
              const selected = filter.column.source === c.source && filter.column.name === c.name ? 'selected' : ''
              return `<option value='${colValue}' ${selected}>${c.source}.${c.name}</option>`
            }).join('')}
          </select>
        </div>
        
        <!-- Operator -->
        <div>
          <label class="block text-xs font-medium text-gray-700 mb-1">Operator</label>
          <select data-action="change->visual-query-builder#updateFilter"
                  data-index="${index}"
                  data-field="operator"
                  class="w-full text-sm rounded border-gray-300 focus:border-yellow-500 focus:ring-yellow-500">
            ${operators.map(op => `<option value="${op}" ${filter.operator === op ? 'selected' : ''}>${op}</option>`).join('')}
          </select>
        </div>
        
        <!-- Value -->
        <div>
          <label class="block text-xs font-medium text-gray-700 mb-1">Value</label>
          <input type="text"
                 data-action="change->visual-query-builder#updateFilter"
                 data-index="${index}"
                 data-field="value"
                 value="${filter.value || ''}"
                 placeholder="Enter value..."
                 class="w-full text-sm rounded border-gray-300 focus:border-yellow-500 focus:ring-yellow-500"
                 ${filter.operator.includes('NULL') ? 'disabled' : ''}>
        </div>
      </div>
      
      <div class="text-xs text-center font-mono text-gray-700 bg-white/70 rounded px-2 py-1">
        WHERE ${filter.column.name || '...'} ${filter.operator} ${filter.operator.includes('NULL') ? '' : (filter.value || '...')}
      </div>
    `
    
    return div
  }

  updateFilter(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    const field = event.currentTarget.dataset.field
    const value = event.currentTarget.value
    
    if (field === 'column') {
      this.config.filters[index].column = JSON.parse(value)
    } else {
      this.config.filters[index][field] = value
    }
    
    this.saveConfig()
    this.renderFilters()
    this.updateSqlPreview()
  }

  // Update SQL preview
  async updateSqlPreview() {
    if (!this.hasSqlPreviewTarget) return

    if (this.modeValue === "visual") {
      // Check if we have enough data to generate SQL
      if (this.config.columns.length === 0) {
        this.sqlPreviewTarget.textContent = "-- Add columns to see SQL preview"
        return
      }

      // Generate SQL preview client-side (simple version)
      // For production, you'd want to call the backend
      try {
        const sql = this.generateSimpleSql()
        this.sqlPreviewTarget.textContent = sql
      } catch (error) {
        console.error("Failed to generate SQL:", error)
        this.sqlPreviewTarget.textContent = `-- Error: ${error.message}`
      }
    } else {
      // Show current SQL
      if (this.hasSqlInputTarget) {
        this.sqlPreviewTarget.textContent = this.sqlInputTarget.value
      }
    }
  }

  // Simple client-side SQL generation for preview
  generateSimpleSql() {
    const parts = []

    // SELECT clause
    const columns = this.config.columns.map(col => {
      if (col.type === 'source_column') {
        const qualified = `${col.source}.${col.name}`
        return col.alias ? `${qualified} AS ${col.alias}` : qualified
      } else if (col.type === 'aggregate') {
        const func = col.function === 'COUNT_DISTINCT' ? 'COUNT(DISTINCT' : col.function + '('
        const closeFunc = col.function === 'COUNT_DISTINCT' ? ')' : ''
        const qualified = `${col.column.source}.${col.column.name}`
        const alias = col.alias || `${col.function.toLowerCase()}_${col.column.name}`
        return `${func}${qualified}${closeFunc}) AS ${alias}`
      }
      return ''
    }).filter(Boolean)

    parts.push('SELECT')
    parts.push('  ' + columns.join(',\n  '))

    // FROM clause (assumes first source for now)
    if (this.config.sources && this.config.sources.length > 0) {
      parts.push(`FROM ${this.config.sources[0].alias}`)
    } else {
      // Use the first table mentioned in columns
      const firstTable = this.config.columns[0]?.source || 'table_name'
      parts.push(`FROM ${firstTable}`)
    }

    // WHERE clause
    if (this.config.filters && this.config.filters.length > 0) {
      const filters = this.config.filters
        .filter(f => f.column.name && f.operator)
        .map(f => {
          const col = `${f.column.source}.${f.column.name}`
          if (f.operator.includes('NULL')) {
            return `${col} ${f.operator.replace('_', ' ')}`
          }
          const value = typeof f.value === 'string' ? `'${f.value}'` : f.value
          return `${col} ${f.operator} ${value}`
        })
      
      if (filters.length > 0) {
        parts.push('WHERE ' + filters.join('\n  AND '))
      }
    }

    // GROUP BY clause
    if (this.config.groupBy && this.config.groupBy.length > 0) {
      const groupCols = this.config.groupBy.map(g => `${g.source}.${g.name}`)
      parts.push('GROUP BY ' + groupCols.join(', '))
    }

    // ORDER BY clause
    if (this.config.orderBy && this.config.orderBy.length > 0) {
      const orderCols = this.config.orderBy.map(o => `${o.source}.${o.name} ${o.direction || 'ASC'}`)
      parts.push('ORDER BY ' + orderCols.join(', '))
    }

    // LIMIT clause
    if (this.config.limit) {
      parts.push(`LIMIT ${this.config.limit}`)
    }

    return parts.join('\n')
  }

  // Save config to hidden input
  saveConfig() {
    if (this.hasConfigInputTarget) {
      this.configInputTarget.value = JSON.stringify(this.config)
    }
  }

  // Update statistics display
  updateStats() {
    const columnCount = document.getElementById('stats-columns')
    const filterCount = document.getElementById('stats-filters')
    const joinCount = document.getElementById('stats-joins')
    const columnCountBadge = document.getElementById('column-count')
    const filterCountBadge = document.getElementById('filter-count')
    const joinCountBadge = document.getElementById('join-count')
    
    if (columnCount) columnCount.textContent = this.config.columns.length
    if (filterCount) filterCount.textContent = this.config.filters.length
    if (joinCount) joinCount.textContent = (this.config.joins || []).length
    
    if (columnCountBadge) columnCountBadge.textContent = this.config.columns.length
    if (filterCountBadge) filterCountBadge.textContent = this.config.filters.length
    if (joinCountBadge) joinCountBadge.textContent = (this.config.joins || []).length
  }
  
  // Refresh column selector highlights
  refreshColumnSelectorState() {
    const columnSelectorEl = document.querySelector('[data-controller="column-selector"]')
    if (!columnSelectorEl) return
    
    const columnSelector = this.application.getControllerForElementAndIdentifier(columnSelectorEl, 'column-selector')
    if (!columnSelector || !columnSelector.refreshSelectedState) return
    
    // Extract selected columns info
    const selectedColumns = this.config.columns.map(col => ({
      source: col.source,
      name: col.name
    }))
    
    columnSelector.refreshSelectedState(selectedColumns)
  }

  // Update column alias from inline input
  updateColumnAlias(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    const column = this.config.columns[index]
    const newAlias = event.currentTarget.value.trim()
    
    // Empty string means remove alias
    column.alias = newAlias || null
    
    this.saveConfig()
    this.updateSqlPreview()
  }

  // Handle Enter key in alias field
  handleAliasKeydown(event) {
    if (event.key === 'Enter') {
      event.preventDefault()
      event.currentTarget.blur() // Trigger blur to save
    }
  }

  // Generate smart default alias for a column
  generateSmartAlias(column) {
    if (column.type === 'source_column') {
      return column.name
    } else if (column.type === 'aggregate') {
      const func = column.function.toLowerCase()
      const colName = column.column.name
      
      // Generate readable aliases like total_revenue, avg_price, etc.
      const prefixMap = {
        'sum': 'total',
        'avg': 'average',
        'count': 'count',
        'min': 'minimum',
        'max': 'maximum',
        'count_distinct': 'unique'
      }
      
      const prefix = prefixMap[func] || func
      return `${prefix}_${colName}`
    }
    
    return 'result'
  }

  // Convert column to aggregate
  convertToAggregate(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    const column = this.config.columns[index]
    
    if (column.type !== 'source_column') return
    
    const functions = ['SUM', 'AVG', 'COUNT', 'MIN', 'MAX', 'COUNT_DISTINCT']
    const choice = prompt(`Choose aggregate function:\n${functions.map((f, i) => `${i+1}. ${f}`).join('\n')}\n\nEnter number (1-${functions.length}):`, '1')
    
    if (choice && choice >= 1 && choice <= functions.length) {
      const func = functions[parseInt(choice) - 1]
      
      // Convert to aggregate
      this.config.columns[index] = {
        type: 'aggregate',
        function: func,
        column: {
          source: column.source,
          name: column.name
        },
        alias: column.alias || `${func.toLowerCase()}_${column.name}`
      }
      
      this.saveConfig()
      this.renderColumns()
      this.updateSqlPreview()
    }
  }

  // Add Group By
  addGroupBy() {
    const sources = this.getAvailableColumns()
    if (sources.length === 0) {
      alert('No columns selected yet. Add columns first.')
      return
    }
    
    this.showGroupByModal(sources)
  }
  
  showGroupByModal(sources) {
    // Create modal
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 z-[100] flex items-center justify-center p-4'
    modal.innerHTML = `
      <!-- Background overlay -->
      <div class="fixed inset-0 bg-gray-900 bg-opacity-50" data-backdrop></div>
      
      <!-- Modal panel -->
      <div class="relative bg-white shadow-2xl max-w-md w-full z-10 overflow-hidden" style="border-radius: 1.5rem; box-shadow: 0 0 100px rgba(0, 0, 0, 0.5), 0 30px 80px rgba(0, 0, 0, 0.4);">
        <!-- Header -->
        <div class="px-6 py-4 bg-alice-secondary">
          <h3 class="text-lg font-bold text-white flex items-center">
            📊 Add Group By Column
          </h3>
        </div>
        
        <!-- Body -->
        <div class="px-6 py-4">
          <p class="text-sm text-gray-600 mb-4">Select a column to group by:</p>
          <div class="space-y-2 max-h-96 overflow-y-auto">
            ${sources.map((s, i) => `
              <button type="button" 
                      class="w-full text-left px-4 py-3 border-2 border-gray-200 rounded-xl hover:border-alice-primary hover:bg-alice-light hover:bg-opacity-10 transition-all font-mono text-sm"
                      data-index="${i}">
                ${s.source}.${s.name}
              </button>
            `).join('')}
          </div>
        </div>
        
        <!-- Footer -->
        <div class="px-6 py-4 bg-gray-50 flex justify-end space-x-3">
          <button type="button" 
                  class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
                  data-cancel>
            Cancel
          </button>
        </div>
      </div>
    `
    
    document.body.appendChild(modal)
    this.currentModal = modal
    
    // Add click handler to backdrop
    modal.querySelector('[data-backdrop]').addEventListener('click', () => this.closeModal())
    
    // Add click handler to cancel button
    modal.querySelector('[data-cancel]').addEventListener('click', () => this.closeModal())
    
    // Add click handlers to column buttons
    modal.querySelectorAll('[data-index]').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const index = parseInt(e.currentTarget.dataset.index)
        const selected = sources[index]
        this.addGroupByColumn(selected)
      })
    })
  }
  
  addGroupByColumn(column) {
    this.config.groupBy.push({
      source: column.source,
      name: column.name
    })
    
    this.saveConfig()
    this.renderGroupBy()
    this.updateSqlPreview()
    this.closeModal()
  }

  removeGroupBy(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    this.config.groupBy.splice(index, 1)
    
    this.saveConfig()
    this.renderGroupBy()
    this.updateSqlPreview()
  }

  renderGroupBy() {
    if (!this.hasGroupByContainerTarget) return

    const container = this.groupByContainerTarget
    container.innerHTML = ""

    if (this.config.groupBy.length === 0) {
      container.innerHTML = `<div class="text-sm text-gray-500 italic">No grouping</div>`
      return
    }

    this.config.groupBy.forEach((group, index) => {
      const div = document.createElement("div")
      div.className = "bg-green-50 border border-green-200 rounded-md p-2 flex items-center justify-between"
      div.innerHTML = `
        <span class="font-mono text-sm text-green-900">📊 ${group.source}.${group.name}</span>
        <button type="button" 
                data-action="click->visual-query-builder#removeGroupBy"
                data-index="${index}"
                class="text-red-600 hover:text-red-800 text-xs">
          Remove
        </button>
      `
      container.appendChild(div)
    })
  }

  // Add Order By
  addOrderBy() {
    const sources = this.getAvailableColumns()
    if (sources.length === 0) {
      alert('No columns selected yet. Add columns first.')
      return
    }
    
    this.showOrderByModal(sources)
  }
  
  showOrderByModal(sources) {
    // Create modal
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 z-[100] flex items-center justify-center p-4'
    modal.innerHTML = `
      <!-- Background overlay -->
      <div class="fixed inset-0 bg-gray-900 bg-opacity-50" data-backdrop></div>
      
      <!-- Modal panel -->
      <div class="relative bg-white shadow-2xl max-w-md w-full z-10 overflow-hidden" style="border-radius: 1.5rem; box-shadow: 0 0 100px rgba(0, 0, 0, 0.5), 0 30px 80px rgba(0, 0, 0, 0.4);">
        <!-- Header -->
        <div class="px-6 py-4 bg-alice-secondary">
          <h3 class="text-lg font-bold text-white flex items-center">
            🔽 Add Sort Column
          </h3>
        </div>
        
        <!-- Body -->
        <div class="px-6 py-4">
          <p class="text-sm text-gray-600 mb-4">Select a column to sort by:</p>
          <div class="space-y-2 max-h-96 overflow-y-auto" data-orderby-list>
            ${sources.map((s, i) => `
              <button type="button" 
                      class="w-full text-left px-4 py-3 border-2 border-gray-200 rounded-xl hover:border-alice-primary hover:bg-alice-light hover:bg-opacity-10 transition-all font-mono text-sm"
                      data-index="${i}">
                ${s.source}.${s.name}
              </button>
            `).join('')}
          </div>
        </div>
        
        <!-- Footer -->
        <div class="px-6 py-4 bg-gray-50 flex justify-end space-x-3">
          <button type="button" 
                  class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
                  data-cancel>
            Cancel
          </button>
        </div>
      </div>
    `
    
    document.body.appendChild(modal)
    this.currentModal = modal
    
    // Add click handler to backdrop
    modal.querySelector('[data-backdrop]').addEventListener('click', () => this.closeModal())
    
    // Add click handler to cancel button
    modal.querySelector('[data-cancel]').addEventListener('click', () => this.closeModal())
    
    // Add click handlers to column buttons
    modal.querySelectorAll('[data-index]').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const index = parseInt(e.currentTarget.dataset.index)
        const selected = sources[index]
        this.showDirectionModal(selected)
      })
    })
  }
  
  showDirectionModal(column) {
    // Close the column selection modal
    if (this.currentModal) {
      this.currentModal.remove()
    }
    
    // Create direction modal
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 z-[100] flex items-center justify-center p-4'
    modal.innerHTML = `
      <!-- Background overlay -->
      <div class="fixed inset-0 bg-gray-900 bg-opacity-50" data-backdrop></div>
      
      <!-- Modal panel -->
      <div class="relative bg-white shadow-2xl max-w-md w-full z-10 overflow-hidden" style="border-radius: 1.5rem; box-shadow: 0 0 100px rgba(0, 0, 0, 0.5), 0 30px 80px rgba(0, 0, 0, 0.4);">
        <!-- Header -->
        <div class="px-6 py-4 bg-alice-secondary">
          <h3 class="text-lg font-bold text-white flex items-center">
            🔽 Sort Direction
          </h3>
        </div>
        
        <!-- Body -->
        <div class="px-6 py-4">
          <p class="text-sm text-gray-600 mb-4">How do you want to sort <span class="font-mono font-bold">${column.source}.${column.name}</span>?</p>
          <div class="space-y-3">
            <button type="button" 
                    class="w-full text-left px-4 py-4 border-2 border-gray-200 rounded-lg hover:border-alice-primary hover:bg-alice-light hover:bg-opacity-10 transition-all"
                    data-direction="ASC">
              <div class="flex items-center space-x-3">
                <span class="text-2xl">↑</span>
                <div>
                  <div class="font-bold text-gray-900">Ascending</div>
                  <div class="text-xs text-gray-600">A → Z, 0 → 9, oldest → newest</div>
                </div>
              </div>
            </button>
            <button type="button" 
                    class="w-full text-left px-4 py-4 border-2 border-gray-200 rounded-lg hover:border-alice-primary hover:bg-alice-light hover:bg-opacity-10 transition-all"
                    data-direction="DESC">
              <div class="flex items-center space-x-3">
                <span class="text-2xl">↓</span>
                <div>
                  <div class="font-bold text-gray-900">Descending</div>
                  <div class="text-xs text-gray-600">Z → A, 9 → 0, newest → oldest</div>
                </div>
              </div>
            </button>
          </div>
        </div>
        
        <!-- Footer -->
        <div class="px-6 py-4 bg-gray-50 flex justify-end space-x-3">
          <button type="button" 
                  class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
                  data-cancel>
            Cancel
          </button>
        </div>
      </div>
    `
    
    document.body.appendChild(modal)
    this.currentModal = modal
    
    // Add click handler to backdrop
    modal.querySelector('[data-backdrop]').addEventListener('click', () => this.closeModal())
    
    // Add click handler to cancel button
    modal.querySelector('[data-cancel]').addEventListener('click', () => this.closeModal())
    
    // Add click handlers to direction buttons
    modal.querySelectorAll('[data-direction]').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const direction = e.currentTarget.dataset.direction
        this.addOrderByColumn(column, direction)
      })
    })
  }
  
  addOrderByColumn(column, direction) {
    this.config.orderBy.push({
      source: column.source,
      name: column.name,
      direction: direction
    })
    
    this.saveConfig()
    this.renderOrderBy()
    this.updateSqlPreview()
    this.closeModal()
  }
  
  closeModal() {
    if (this.currentModal) {
      this.currentModal.remove()
      this.currentModal = null
    }
  }

  removeOrderBy(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    this.config.orderBy.splice(index, 1)
    
    this.saveConfig()
    this.renderOrderBy()
    this.updateSqlPreview()
  }

  renderOrderBy() {
    if (!this.hasOrderByContainerTarget) return

    const container = this.orderByContainerTarget
    container.innerHTML = ""
    
    // Filter out invalid entries
    this.config.orderBy = this.config.orderBy.filter(order => order && order.source && order.name)

    if (this.config.orderBy.length === 0) {
      container.innerHTML = `<div class="text-sm text-gray-500 italic">No sorting</div>`
      return
    }

    this.config.orderBy.forEach((order, index) => {
      const div = document.createElement("div")
      div.className = "bg-orange-50 border border-orange-200 rounded-md p-2 flex items-center justify-between"
      div.innerHTML = `
        <span class="font-mono text-sm text-orange-900">${order.direction === 'ASC' ? '↑' : '↓'} ${order.source}.${order.name}</span>
        <button type="button" 
                data-action="click->visual-query-builder#removeOrderBy"
                data-index="${index}"
                class="text-red-600 hover:text-red-800 text-xs">
          Remove
        </button>
      `
      container.appendChild(div)
    })
  }

  getAvailableColumns() {
    const columns = []
    this.config.columns.forEach(col => {
      if (col.type === 'source_column') {
        columns.push({ source: col.source, name: col.name })
      } else if (col.type === 'aggregate') {
        columns.push({ source: col.column.source, name: col.column.name })
      }
    })
    return columns
  }

  handleDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'copy'
    
    // Add visual feedback to drop zone
    event.currentTarget.classList.add('bg-blue-50', 'border-blue-300')
  }

  handleDrop(event) {
    event.preventDefault()
    
    // Remove visual feedback
    event.currentTarget.classList.remove('bg-blue-50', 'border-blue-300')
    
    try {
      const columnData = JSON.parse(event.dataTransfer.getData('application/json'))
      
      // Add the column
      this.config.columns.push({
        type: "source_column",
        source: columnData.source,
        name: columnData.name,
        alias: null
      })

      this.saveConfig()
      this.renderColumns()
      this.updateSqlPreview()
      
      // Visual feedback
      console.log('Column added via drag and drop:', columnData)
    } catch (error) {
      console.error('Failed to add column via drag and drop:', error)
    }
  }

  getCsrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  // Progressive disclosure: Show Group By and Order By sections after first column is added
  updateAdvancedSectionsVisibility() {
    // Only show once and only if we have at least one column
    if (this.advancedSectionsRevealed || this.config.columns.length === 0) {
      return
    }

    // Check if targets exist
    if (!this.hasAdvancedSectionsTarget || !this.hasAdvancedBannerTarget) {
      return
    }

    // Show the sections with smooth animation
    this.advancedSectionsRevealed = true

    // Show banner first
    const banner = this.advancedBannerTarget
    banner.style.display = 'block'
    banner.style.opacity = '0'
    banner.style.transform = 'translateY(-10px)'
    banner.style.transition = 'opacity 0.4s ease-out, transform 0.4s ease-out'

    // Force reflow
    banner.offsetHeight

    // Animate in
    banner.style.opacity = '1'
    banner.style.transform = 'translateY(0)'

    // Show sections slightly after banner
    setTimeout(() => {
      const sections = this.advancedSectionsTarget
      sections.style.display = 'grid'
      sections.style.opacity = '0'
      sections.style.transform = 'translateY(-10px)'
      sections.style.transition = 'opacity 0.4s ease-out, transform 0.4s ease-out'

      // Force reflow
      sections.offsetHeight

      // Animate in
      sections.style.opacity = '1'
      sections.style.transform = 'translateY(0)'

      // Hide banner after 5 seconds
      setTimeout(() => {
        banner.style.opacity = '0'
        setTimeout(() => {
          banner.style.display = 'none'
        }, 400)
      }, 5000)
    }, 200)
  }

  // Quick Start Templates
  updateQuickStartVisibility() {
    if (!this.hasQuickStartPanelTarget) return
    
    // Check if user has dismissed Quick Start
    const dismissed = sessionStorage.getItem('vqb-quickstart-dismissed') === 'true'
    
    // Show Quick Start only if:
    // 1. Not dismissed
    // 2. No columns exist
    if (!dismissed && this.config.columns.length === 0) {
      this.quickStartPanelTarget.style.display = 'block'
    } else {
      this.quickStartPanelTarget.style.display = 'none'
    }
  }

  dismissQuickStart() {
    sessionStorage.setItem('vqb-quickstart-dismissed', 'true')
    this.updateQuickStartVisibility()
  }

  applyTemplate(event) {
    const template = event.currentTarget.dataset.template
    
    // Get available data sources from column selector
    const columnSelectorController = this.application.getControllerForElementAndIdentifier(
      document.querySelector('[data-controller*="column-selector"]'),
      'column-selector'
    )
    
    if (!columnSelectorController || !columnSelectorController.mockSources) {
      console.error('Column selector not available')
      return
    }
    
    const sources = columnSelectorController.mockSources
    const sourceNames = Object.keys(sources)
    
    if (sourceNames.length === 0) {
      alert('No data sources available')
      return
    }
    
    // Clear existing config
    this.config.columns = []
    this.config.filters = []
    this.config.joins = []
    this.config.groupBy = []
    this.config.orderBy = []
    this.config.limit = null
    
    // Apply template
    switch (template) {
      case 'simple-select':
        this.applySimpleSelectTemplate(sources, sourceNames[0])
        break
      case 'join-two-tables':
        this.applyJoinTwoTablesTemplate(sources, sourceNames)
        break
      case 'aggregation':
        this.applyAggregationTemplate(sources, sourceNames[0])
        break
      case 'time-series':
        this.applyTimeSeriesTemplate(sources, sourceNames[0])
        break
    }
    
    // Update UI
    this.saveConfig()
    this.renderColumns()
    this.renderFilters()
    this.renderGroupBy()
    this.renderOrderBy()
    this.updateSqlPreview()
    this.updateAdvancedSectionsVisibility()
    this.updateQuickStartVisibility()
    this.refreshColumnSelectorState()
  }

  applySimpleSelectTemplate(sources, sourceName) {
    // Add all columns from first table
    const columns = sources[sourceName]
    columns.forEach(col => {
      this.config.columns.push({
        type: 'source_column',
        source: sourceName,
        name: col.name,
        alias: null
      })
    })
  }

  applyJoinTwoTablesTemplate(sources, sourceNames) {
    if (sourceNames.length < 2) {
      // Fall back to simple select if only one source
      this.applySimpleSelectTemplate(sources, sourceNames[0])
      return
    }
    
    const source1 = sourceNames[0]
    const source2 = sourceNames[1]
    
    // Add key columns from both tables
    const cols1 = sources[source1]
    const cols2 = sources[source2]
    
    // Add first few columns from each table
    cols1.slice(0, 3).forEach(col => {
      this.config.columns.push({
        type: 'source_column',
        source: source1,
        name: col.name,
        alias: null
      })
    })
    
    cols2.slice(0, 3).forEach(col => {
      this.config.columns.push({
        type: 'source_column',
        source: source2,
        name: col.name,
        alias: null
      })
    })
    
    // Create a join between the two tables
    // Try to find matching column names
    let joinColumn = ''
    for (const col1 of cols1) {
      if (cols2.some(col2 => col2.name === col1.name)) {
        joinColumn = col1.name
        break
      }
    }
    
    // If no exact match, look for _id columns
    if (!joinColumn) {
      const idCol = cols1.find(c => c.name.includes('_id'))
      if (idCol && cols2.some(c => c.name === idCol.name)) {
        joinColumn = idCol.name
      }
    }
    
    // Create the join
    this.config.joins.push({
      type: 'INNER',
      leftTable: source1,
      leftColumn: joinColumn || cols1[0].name,
      rightTable: source2,
      rightColumn: joinColumn || cols2[0].name
    })
    
    // Notify join-builder to update its display
    this.updateJoinBuilderFromConfig()
  }

  applyAggregationTemplate(sources, sourceName) {
    const columns = sources[sourceName]
    
    if (columns.length === 0) return
    
    // Add COUNT(*) as aggregate
    this.config.columns.push({
      type: 'aggregate',
      function: 'count',
      column: { source: sourceName, name: '*' },
      alias: 'count'
    })
    
    // Add first column as group by
    const firstCol = columns[0]
    this.config.columns.push({
      type: 'source_column',
      source: sourceName,
      name: firstCol.name,
      alias: null
    })
    
    this.config.groupBy.push({
      source: sourceName,
      name: firstCol.name
    })
    
    // Order by count DESC
    this.config.orderBy.push({
      source: sourceName,
      name: 'count',
      direction: 'DESC'
    })
  }

  applyTimeSeriesTemplate(sources, sourceName) {
    const columns = sources[sourceName]
    
    if (columns.length === 0) return
    
    // Try to find a date column
    const dateCol = columns.find(c => 
      c.type === 'date' || c.type === 'timestamp' || 
      c.name.toLowerCase().includes('date') || c.name.toLowerCase().includes('time')
    ) || columns[0]
    
    // Add date column
    this.config.columns.push({
      type: 'source_column',
      source: sourceName,
      name: dateCol.name,
      alias: null
    })
    
    // Try to find numeric columns for metrics
    const numericCols = columns.filter(c => 
      c.type === 'integer' || c.type === 'decimal' || c.type === 'float'
    )
    
    if (numericCols.length > 0) {
      // Add first numeric column with SUM
      this.config.columns.push({
        type: 'aggregate',
        function: 'sum',
        column: { source: sourceName, name: numericCols[0].name },
        alias: this.generateSmartAlias({
          type: 'aggregate',
          function: 'sum',
          column: { source: sourceName, name: numericCols[0].name }
        })
      })
    }
    
    // Order by date DESC
    this.config.orderBy.push({
      source: sourceName,
      name: dateCol.name,
      direction: 'DESC'
    })
    
    // Add LIMIT 100
    this.config.limit = 100
  }
}
