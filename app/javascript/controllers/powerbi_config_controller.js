import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="powerbi-config"
export default class extends Controller {
  static targets = ["fields", "workspaceSelect", "manualInput", "manualField", "hiddenField"]
  
  connect() {
    // Initialize field visibility on page load
    this.toggleFields()
  }
  
  async toggleFields() {
    const select = this.element.querySelector('select[name="pipeline[destination_connector_id]"]')
    const selectedOption = select?.options[select.selectedIndex]
    
    if (!selectedOption || !this.hasFieldsTarget) {
      return
    }
    
    // Check if selected connector is Power BI by looking at the option text
    const isPowerBI = selectedOption.text.toLowerCase().includes('powerbi')
    const connectorId = selectedOption.value
    
    if (isPowerBI && connectorId) {
      this.fieldsTarget.classList.remove('hidden')
      await this.fetchWorkspaces(connectorId)
    } else {
      this.fieldsTarget.classList.add('hidden')
    }
  }
  
  async fetchWorkspaces(connectorId) {
    if (!this.hasWorkspaceSelectTarget) return
    
    const workspaceSelect = this.workspaceSelectTarget
    workspaceSelect.disabled = true
    workspaceSelect.innerHTML = '<option value="">Loading workspaces...</option>'
    
    try {
      const response = await fetch(`/connectors/${connectorId}/powerbi_workspaces`)
      const data = await response.json()
      
      if (response.ok && data.workspaces) {
        workspaceSelect.innerHTML = '<option value="">Select a workspace...</option>'
        data.workspaces.forEach(workspace => {
          const option = document.createElement('option')
          option.value = workspace.id
          option.textContent = workspace.name
          workspaceSelect.appendChild(option)
        })
        workspaceSelect.disabled = false
      } else {
        workspaceSelect.innerHTML = '<option value="">Failed to load workspaces</option>'
        this.showManualInput()
        console.error('Failed to fetch workspaces:', data.error)
      }
    } catch (error) {
      workspaceSelect.innerHTML = '<option value="">Error loading workspaces</option>'
      this.showManualInput()
      console.error('Error fetching workspaces:', error)
    }
  }
  
  showManualInput() {
    if (this.hasManualInputTarget) {
      this.manualInputTarget.classList.remove('hidden')
    }
  }
  
  syncToHiddenField() {
    if (!this.hasHiddenFieldTarget) return
    
    // Prefer manual field value if it has content, otherwise use select
    const manualValue = this.hasManualFieldTarget ? this.manualFieldTarget.value.trim() : ''
    const selectValue = this.hasWorkspaceSelectTarget ? this.workspaceSelectTarget.value : ''
    
    this.hiddenFieldTarget.value = manualValue || selectValue
  }
}
