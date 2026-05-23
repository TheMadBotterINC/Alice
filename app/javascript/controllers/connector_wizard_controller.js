import { Controller } from "@hotwired/stimulus"

console.log('Loading connector wizard controller')

// Connects to data-controller="connector-wizard"
export default class extends Controller {
  static targets = ["step", "progress", "nextButton", "backButton", "submitButton"]
  static values = {
    currentStep: { type: Number, default: 1 },
    totalSteps: { type: Number, default: 3 },
    selectedType: String
  }
  
  connect() {
    console.log('Connector wizard controller connected!')
    this.showStep(this.currentStepValue)
    this.updateProgress()
  }
  
  selectType(event) {
    const type = event.currentTarget.dataset.connectorType
    const fileFormat = event.currentTarget.dataset.fileFormat
    
    // For file connectors, append the format to create a unique type
    if (type === 'file' && fileFormat) {
      this.selectedTypeValue = `file_${fileFormat}`
    } else {
      this.selectedTypeValue = type
    }
    
    // Adjust total steps and progress indicators for PostgreSQL (adds PGLake config step)
    const step3Indicator = document.getElementById('step-3-indicator')
    const step3Connector = document.getElementById('step-3-connector')
    const step4Indicator = document.getElementById('step-4-indicator')
    
    if (type === 'postgresql') {
      this.totalStepsValue = 4
      // Show the 4-step progress bar
      step3Indicator?.classList.remove('hidden')
      step3Connector?.classList.remove('hidden')
      // Update step 4 label to "Test & Create"
      const step4Label = step4Indicator?.querySelector('.step-label')
      if (step4Label) step4Label.textContent = 'Test & Create'
    } else {
      this.totalStepsValue = 3
      // Hide the extra step, make it 3-step
      step3Indicator?.classList.add('hidden')
      step3Connector?.classList.add('hidden')
      // Update step 4 label to "Test & Create" (but it will be treated as step 3)
      const step4Label = step4Indicator?.querySelector('.step-label')
      if (step4Label) step4Label.textContent = 'Test & Create'
    }
    
    // Store in hidden field
    const typeInput = this.element.querySelector('input[name="connector[connector_type]"]')
    if (typeInput) {
      typeInput.value = this.selectedTypeValue
    }
    
    // Highlight selected card
    this.element.querySelectorAll('[data-connector-type]').forEach(card => {
      card.classList.remove('ring-2', 'ring-primary', 'border-primary')
      card.classList.add('border-gray-200')
    })
    event.currentTarget.classList.remove('border-gray-200')
    event.currentTarget.classList.add('ring-2', 'ring-primary', 'border-primary')
    
    // Enable next button
    if (this.hasNextButtonTarget) {
      this.nextButtonTarget.disabled = false
      this.nextButtonTarget.classList.remove('opacity-50', 'cursor-not-allowed')
    }
  }
  
  next() {
    if (this.currentStepValue < this.totalStepsValue) {
      // Validate current step before proceeding
      if (this.validateStep(this.currentStepValue)) {
        this.currentStepValue++
        this.showStep(this.currentStepValue)
        this.updateProgress()
        
        // Populate review step if we're moving to it (last step)
        if (this.currentStepValue === this.totalStepsValue) {
          this.populateReview()
        }
        
        // Show PGLake fields on step 3 for PostgreSQL
        if (this.currentStepValue === 3 && this.selectedTypeValue === 'postgresql') {
          this.showPGLakeStep()
        }
      }
    }
  }
  
  back() {
    if (this.currentStepValue > 1) {
      this.currentStepValue--
      this.showStep(this.currentStepValue)
      this.updateProgress()
    }
  }
  
  showStep(stepNumber) {
    this.stepTargets.forEach((step, index) => {
      if (index + 1 === stepNumber) {
        step.classList.remove('hidden')
      } else {
        step.classList.add('hidden')
      }
    })
    
    // Update buttons visibility
    if (this.hasBackButtonTarget) {
      this.backButtonTarget.classList.toggle('hidden', stepNumber === 1)
    }
    
    if (this.hasNextButtonTarget && this.hasSubmitButtonTarget) {
      if (stepNumber === this.totalStepsValue) {
        this.nextButtonTarget.classList.add('hidden')
        this.submitButtonTarget.classList.remove('hidden')
      } else {
        this.nextButtonTarget.classList.remove('hidden')
        this.submitButtonTarget.classList.add('hidden')
      }
    }
    
    // Disable next button on step 1 if no type selected
    if (stepNumber === 1 && !this.selectedTypeValue) {
      if (this.hasNextButtonTarget) {
        this.nextButtonTarget.disabled = true
        this.nextButtonTarget.classList.add('opacity-50', 'cursor-not-allowed')
      }
    }
    
    // Show/hide appropriate config fields on step 2
    if (stepNumber === 2) {
      this.updateFieldVisibility()
    }
    
    // Show PGLake fields on step 3 for PostgreSQL
    if (stepNumber === 3 && this.selectedTypeValue === 'postgresql') {
      this.showPGLakeStep()
    }
  }
  
  updateProgress() {
    const percentage = ((this.currentStepValue - 1) / (this.totalStepsValue - 1)) * 100
    
    if (this.hasProgressTarget) {
      this.progressTarget.style.width = `${percentage}%`
    }
    
    // Update step indicators
    this.element.querySelectorAll('[data-step-number]').forEach(indicator => {
      const stepNum = parseInt(indicator.dataset.stepNumber)
      const circle = indicator.querySelector('.step-circle')
      const label = indicator.querySelector('.step-label')
      
      if (stepNum < this.currentStepValue) {
        // Completed
        circle.classList.remove('bg-gray-200', 'border-gray-300', 'bg-primary', 'border-primary')
        circle.classList.add('bg-green-500', 'border-green-500')
        circle.innerHTML = '<svg class="h-3 w-3 text-white" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/></svg>'
        label.classList.remove('text-gray-500', 'text-primary')
        label.classList.add('text-green-600')
      } else if (stepNum === this.currentStepValue) {
        // Current
        circle.classList.remove('bg-gray-200', 'border-gray-300', 'bg-green-500', 'border-green-500')
        circle.classList.add('bg-primary', 'border-primary')
        circle.textContent = stepNum
        label.classList.remove('text-gray-500', 'text-green-600')
        label.classList.add('text-primary')
      } else {
        // Upcoming
        circle.classList.remove('bg-green-500', 'border-green-500', 'bg-primary', 'border-primary')
        circle.classList.add('bg-gray-200', 'border-gray-300')
        circle.textContent = stepNum
        label.classList.remove('text-primary', 'text-green-600')
        label.classList.add('text-gray-500')
      }
    })
  }
  
  validateStep(stepNumber) {
    if (stepNumber === 1) {
      return !!this.selectedTypeValue
    }
    
    if (stepNumber === 2) {
      // Validate configuration fields - only check visible required fields
      const form = this.element.querySelector('form')
      const visibleStep = this.element.querySelector('[data-connector-wizard-target="step"]:not(.hidden)')
      const requiredFields = visibleStep.querySelectorAll('[required]')
      let valid = true
      
      requiredFields.forEach(field => {
        // Only validate if the field is actually visible (not in a hidden parent)
        const isVisible = field.offsetParent !== null
        if (isVisible && (!field.value || field.value.trim() === '')) {
          valid = false
          field.classList.add('border-red-500')
        } else {
          field.classList.remove('border-red-500')
        }
      })
      
      if (!valid) {
        window.showError('Required Fields Missing', 'Please fill in all required fields before continuing.')
      }
      
      return valid
    }
    
    return true
  }
  
  populateReview() {
    const form = this.element.querySelector('form')
    const reviewContainer = document.getElementById('review-details')
    
    if (!reviewContainer) return
    
    // Get form values
    const name = form.querySelector('[name="connector[name]"]')?.value || 'N/A'
    const type = this.selectedTypeValue || 'N/A'
    
    // Build review HTML based on connector type
    let configHTML = ''
    
    if (type === 'snowflake') {
      const account = form.querySelector('[name="connector[config][account]"]')?.value || 'N/A'
      const username = form.querySelector('[name="connector[config][username]"]')?.value || 'N/A'
      const database = form.querySelector('[name="connector[config][database]"]')?.value || 'N/A'
      const warehouse = form.querySelector('[name="connector[config][warehouse]"]')?.value || 'N/A'
      const schema = form.querySelector('[name="connector[config][schema]"]')?.value || 'PUBLIC'
      const role = form.querySelector('[name="connector[config][role]"]')?.value || 'Not specified'
      
      configHTML = `
        <div class="space-y-3">
          <div>
            <dt class="text-sm font-medium text-gray-500">Account</dt>
            <dd class="mt-1 text-sm text-gray-900">${account}</dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">Username</dt>
            <dd class="mt-1 text-sm text-gray-900">${username}</dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">Database</dt>
            <dd class="mt-1 text-sm text-gray-900">${database}</dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">Warehouse</dt>
            <dd class="mt-1 text-sm text-gray-900">${warehouse}</dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">Schema</dt>
            <dd class="mt-1 text-sm text-gray-900">${schema}</dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">Role</dt>
            <dd class="mt-1 text-sm text-gray-900">${role}</dd>
          </div>
        </div>
      `
    } else if (type === 'duckdb') {
      const databasePath = form.querySelector('[name="connector[config][database_path]"]')?.value || 'N/A'
      const readOnly = form.querySelector('[name="connector[config][read_only]"]')?.checked || false
      
      configHTML = `
        <div class="space-y-3">
          <div>
            <dt class="text-sm font-medium text-gray-500">Database Path</dt>
            <dd class="mt-1 text-sm text-gray-900">${databasePath}</dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">Read-Only Mode</dt>
            <dd class="mt-1 text-sm text-gray-900">${readOnly ? 'Enabled' : 'Disabled'}</dd>
          </div>
        </div>
      `
    } else if (type === 'file_csv') {
      const mode = form.querySelector('[name="connector[config][mode]"]:checked')?.value || 'file_path'
      const filePath = form.querySelector('[name="connector[config][file_path]"]')?.value || 'N/A'
      const hasHeader = form.querySelector('[name="connector[config][has_header]"]')?.checked || false
      const delimiter = form.querySelector('[name="connector[config][delimiter]"]')?.value || ','
      
      let filePathHTML = ''
      if (mode === 'download') {
        filePathHTML = `
          <div>
            <dt class="text-sm font-medium text-gray-500">Output Mode</dt>
            <dd class="mt-1 text-sm text-gray-900">
              <span class="inline-flex items-center px-2 py-1 rounded-md text-sm bg-green-100 text-green-800">💾 Generate for Download</span>
              <p class="text-xs text-gray-500 mt-1">File will be generated after each pipeline run</p>
            </dd>
          </div>
        `
      } else {
        filePathHTML = `
          <div>
            <dt class="text-sm font-medium text-gray-500">Output Mode</dt>
            <dd class="mt-1 text-sm text-gray-900">
              <span class="inline-flex items-center px-2 py-1 rounded-md text-sm bg-blue-100 text-blue-800">📁 Save to File Path</span>
            </dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">File Path</dt>
            <dd class="mt-1 text-sm text-gray-900">${filePath}</dd>
          </div>
        `
      }
      
      configHTML = `
        <div class="space-y-3">
          ${filePathHTML}
          <div>
            <dt class="text-sm font-medium text-gray-500">Delimiter</dt>
            <dd class="mt-1 text-sm text-gray-900">${delimiter === ',' ? 'Comma (,)' : delimiter === '\t' ? 'Tab (TSV)' : delimiter}</dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">Has Header Row</dt>
            <dd class="mt-1 text-sm text-gray-900">${hasHeader ? 'Yes' : 'No'}</dd>
          </div>
        </div>
      `
    } else if (type === 'file_excel') {
      const mode = form.querySelector('[name="connector[config][mode]"]:checked')?.value || 'file_path'
      const filePath = form.querySelector('[name="connector[config][file_path]"]')?.value || 'N/A'
      const sheetName = form.querySelector('[name="connector[config][sheet_name]"]')?.value || 'First sheet'
      const hasHeader = form.querySelector('[name="connector[config][has_header]"]')?.checked || false
      
      let filePathHTML = ''
      if (mode === 'download') {
        filePathHTML = `
          <div>
            <dt class="text-sm font-medium text-gray-500">Output Mode</dt>
            <dd class="mt-1 text-sm text-gray-900">
              <span class="inline-flex items-center px-2 py-1 rounded-md text-sm bg-green-100 text-green-800">💾 Generate for Download</span>
              <p class="text-xs text-gray-500 mt-1">File will be generated after each pipeline run</p>
            </dd>
          </div>
        `
      } else {
        filePathHTML = `
          <div>
            <dt class="text-sm font-medium text-gray-500">Output Mode</dt>
            <dd class="mt-1 text-sm text-gray-900">
              <span class="inline-flex items-center px-2 py-1 rounded-md text-sm bg-blue-100 text-blue-800">📁 Save to File Path</span>
            </dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">File Path</dt>
            <dd class="mt-1 text-sm text-gray-900">${filePath}</dd>
          </div>
        `
      }
      
      configHTML = `
        <div class="space-y-3">
          ${filePathHTML}
          <div>
            <dt class="text-sm font-medium text-gray-500">Sheet Name</dt>
            <dd class="mt-1 text-sm text-gray-900">${sheetName}</dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">Has Header Row</dt>
            <dd class="mt-1 text-sm text-gray-900">${hasHeader ? 'Yes' : 'No'}</dd>
          </div>
        </div>
      `
    } else if (type === 'postgresql') {
      const host = form.querySelector('[name="connector[config][host]"]')?.value || 'N/A'
      const port = form.querySelector('[name="connector[config][port]"]')?.value || '5432'
      const database = form.querySelector('[name="connector[config][database]"]')?.value || 'N/A'
      const username = form.querySelector('[name="connector[config][username]"]')?.value || 'N/A'
      const schema = form.querySelector('[name="connector[config][schema]"]')?.value || 'public'
      
      configHTML = `
        <div class="space-y-3">
          <div>
            <dt class="text-sm font-medium text-gray-500">Host</dt>
            <dd class="mt-1 text-sm text-gray-900">${host}</dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">Port</dt>
            <dd class="mt-1 text-sm text-gray-900">${port}</dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">Database</dt>
            <dd class="mt-1 text-sm text-gray-900">${database}</dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">Schema</dt>
            <dd class="mt-1 text-sm text-gray-900">${schema}</dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">Username</dt>
            <dd class="mt-1 text-sm text-gray-900">${username}</dd>
          </div>
        </div>
      `
    } else if (type === 'file_upload') {
      configHTML = `
        <div class="space-y-3">
          <div>
            <dt class="text-sm font-medium text-gray-500">Upload Mode</dt>
            <dd class="mt-1 text-sm text-gray-900">
              <span class="inline-flex items-center px-2 py-1 rounded-md text-sm bg-blue-100 text-blue-800">📤 Upload at Pipeline Run Time</span>
              <p class="text-xs text-gray-500 mt-1">File will be uploaded when running the pipeline</p>
            </dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">Supported Formats</dt>
            <dd class="mt-1 text-sm text-gray-900">
              <div class="flex flex-wrap gap-2">
                <span class="inline-flex items-center px-2 py-1 rounded-md text-xs bg-gray-100 text-gray-700">CSV</span>
                <span class="inline-flex items-center px-2 py-1 rounded-md text-xs bg-gray-100 text-gray-700">TSV</span>
                <span class="inline-flex items-center px-2 py-1 rounded-md text-xs bg-gray-100 text-gray-700">Excel (.xlsx, .xls)</span>
              </div>
              <p class="text-xs text-gray-500 mt-1">Format will be automatically detected from file extension and content</p>
            </dd>
          </div>
        </div>
      `
    } else if (type === 'powerbi') {
      const tenantId = form.querySelector('[name="connector[config][tenant_id]"]')?.value || 'N/A'
      const clientId = form.querySelector('[name="connector[config][client_id]"]')?.value || 'N/A'
      
      configHTML = `
        <div class="space-y-3">
          <div>
            <dt class="text-sm font-medium text-gray-500">Tenant ID</dt>
            <dd class="mt-1 text-sm text-gray-900 font-mono text-xs">${tenantId}</dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">Client ID</dt>
            <dd class="mt-1 text-sm text-gray-900 font-mono text-xs">${clientId}</dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">Client Secret</dt>
            <dd class="mt-1 text-sm text-gray-900">•••••••• (hidden)</dd>
          </div>
        </div>
      `
    } else if (type === 'sharepoint') {
      const tenantId = form.querySelector('[name="connector[config][tenant_id]"]')?.value || 'N/A'
      const clientId = form.querySelector('[name="connector[config][client_id]"]')?.value || 'N/A'
      const siteId = form.querySelector('[name="connector[config][site_id]"]')?.value || ''
      const siteUrl = form.querySelector('[name="connector[config][site_url]"]')?.value || ''
      const filePath = form.querySelector('[name="connector[config][file_path]"]')?.value || 'N/A'
      
      let siteHTML = ''
      if (siteId) {
        siteHTML = `
          <div>
            <dt class="text-sm font-medium text-gray-500">Site ID</dt>
            <dd class="mt-1 text-sm text-gray-900 font-mono text-xs">${siteId}</dd>
          </div>
        `
      } else if (siteUrl) {
        siteHTML = `
          <div>
            <dt class="text-sm font-medium text-gray-500">Site URL</dt>
            <dd class="mt-1 text-sm text-gray-900">${siteUrl}</dd>
          </div>
        `
      }
      
      configHTML = `
        <div class="space-y-3">
          <div>
            <dt class="text-sm font-medium text-gray-500">Tenant ID</dt>
            <dd class="mt-1 text-sm text-gray-900 font-mono text-xs">${tenantId}</dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">Client ID</dt>
            <dd class="mt-1 text-sm text-gray-900 font-mono text-xs">${clientId}</dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">Client Secret</dt>
            <dd class="mt-1 text-sm text-gray-900">•••••••• (hidden)</dd>
          </div>
          ${siteHTML}
          <div>
            <dt class="text-sm font-medium text-gray-500">File Path</dt>
            <dd class="mt-1 text-sm text-gray-900 font-mono text-sm">${filePath}</dd>
          </div>
        </div>
      `
    }
    
    reviewContainer.innerHTML = `
      <div class="space-y-6">
        <div>
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Connector Details</h3>
          <div class="space-y-3">
            <div>
              <dt class="text-sm font-medium text-gray-500">Name</dt>
              <dd class="mt-1 text-sm text-gray-900">${name}</dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Type</dt>
              <dd class="mt-1 text-sm text-gray-900">${this.formatType(type)}</dd>
            </div>
          </div>
        </div>
        
        <div class="border-t border-gray-200 pt-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Configuration</h3>
          ${configHTML}
        </div>
      </div>
    `
  }
  
  formatType(type) {
    const types = {
      'snowflake': 'Snowflake',
      'duckdb': 'DuckDB',
      'postgresql': 'PostgreSQL',
      'powerbi': 'Power BI',
      'file_csv': 'CSV / TSV Files',
      'file_excel': 'Excel Files',
      'file_upload': 'File Upload (Auto-detect)',
      'sharepoint': 'SharePoint'
    }
    return types[type] || type
  }
  
  updateFieldVisibility() {
    const type = this.selectedTypeValue
    const snowflakeFields = document.getElementById('snowflake-fields')
    const duckdbFields = document.getElementById('duckdb-fields')
    const postgresqlFields = document.getElementById('postgresql-fields')
    const powerbiFields = document.getElementById('powerbi-fields')
    const csvFields = document.getElementById('csv-fields')
    const excelFields = document.getElementById('excel-fields')
    const fileUploadFields = document.getElementById('file_upload-fields')
    const sharepointFields = document.getElementById('sharepoint-fields')
    
    // Hide all field groups first
    snowflakeFields?.classList.add('hidden')
    duckdbFields?.classList.add('hidden')
    postgresqlFields?.classList.add('hidden')
    powerbiFields?.classList.add('hidden')
    csvFields?.classList.add('hidden')
    excelFields?.classList.add('hidden')
    fileUploadFields?.classList.add('hidden')
    sharepointFields?.classList.add('hidden')
    
    // Remove all required attributes from all connector config fields
    const configFields = [
      snowflakeFields, duckdbFields, postgresqlFields, powerbiFields,
      csvFields, excelFields, fileUploadFields, sharepointFields
    ]
    configFields.forEach(container => {
      container?.querySelectorAll('[required]').forEach(field => {
        field.removeAttribute('required')
      })
    })
    
    if (type === 'snowflake') {
      snowflakeFields?.classList.remove('hidden')
      snowflakeFields?.querySelectorAll('[name="connector[config][account]"], [name="connector[config][username]"], [name="connector[config][private_key]"], [name="connector[config][database]"], [name="connector[config][warehouse]"]').forEach(field => {
        field.setAttribute('required', 'required')
      })
    } else if (type === 'duckdb') {
      duckdbFields?.classList.remove('hidden')
      duckdbFields?.querySelectorAll('[name="connector[config][database_path]"]').forEach(field => {
        field.setAttribute('required', 'required')
      })
    } else if (type === 'postgresql') {
      postgresqlFields?.classList.remove('hidden')
      postgresqlFields?.querySelectorAll('[name="connector[config][host]"], [name="connector[config][database]"], [name="connector[config][username]"], [name="connector[config][password]"]').forEach(field => {
        field.setAttribute('required', 'required')
      })
    } else if (type === 'powerbi') {
      powerbiFields?.classList.remove('hidden')
      powerbiFields?.querySelectorAll('[name="connector[config][tenant_id]"], [name="connector[config][client_id]"], [name="connector[config][client_secret]"]').forEach(field => {
        field.setAttribute('required', 'required')
      })
    } else if (type === 'file_csv') {
      csvFields?.classList.remove('hidden')
      csvFields?.querySelectorAll('[name="connector[config][file_path]"]').forEach(field => {
        field.setAttribute('required', 'required')
      })
    } else if (type === 'file_excel') {
      excelFields?.classList.remove('hidden')
      excelFields?.querySelectorAll('[name="connector[config][file_path]"]').forEach(field => {
        field.setAttribute('required', 'required')
      })
    } else if (type === 'file_upload') {
      fileUploadFields?.classList.remove('hidden')
      // No required fields - file is uploaded at pipeline run time
    } else if (type === 'sharepoint') {
      sharepointFields?.classList.remove('hidden')
      sharepointFields?.querySelectorAll('[name="connector[config][tenant_id]"], [name="connector[config][client_id]"], [name="connector[config][client_secret]"], [name="connector[config][file_path]"]').forEach(field => {
        field.setAttribute('required', 'required')
      })
    }
  }
  
  showPGLakeStep() {
    const pglakeFields = document.getElementById('postgresql-pglake-fields')
    if (pglakeFields) {
      pglakeFields.classList.remove('hidden')
    }
  }
  
  togglePGLakeFields(event) {
    const pglakeConfigFields = document.getElementById('pglake-config-fields')
    if (pglakeConfigFields) {
      if (event.target.checked) {
        pglakeConfigFields.classList.remove('hidden')
      } else {
        pglakeConfigFields.classList.add('hidden')
      }
    }
  }
}
