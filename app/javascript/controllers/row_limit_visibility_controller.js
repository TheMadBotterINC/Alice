import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="row-limit-visibility"
export default class extends Controller {
  static values = {
    connectors: Array
  }

  connect() {
    this.updateVisibility()
    
    // Listen for changes to connector checkboxes
    document.addEventListener('change', (e) => {
      if (e.target.matches('input[name="pipeline[source_connector_ids][]"]')) {
        this.updateVisibility()
      }
    })
    
    // Listen for source type radio changes
    document.addEventListener('change', (e) => {
      if (e.target.matches('input[name="source_type"]')) {
        this.updateVisibility()
      }
    })
  }

  updateVisibility() {
    // Check which source type is selected
    const sourceTypeRadio = document.querySelector('input[name="source_type"]:checked')
    const sourceType = sourceTypeRadio?.value
    
    // If datasets are selected, always show the row limit field
    if (sourceType === 'datasets') {
      this.show()
      return
    }
    
    // If connectors are selected, check if any non-file connectors are checked
    if (sourceType === 'connectors') {
      const checkedConnectorIds = Array.from(
        document.querySelectorAll('input[name="pipeline[source_connector_ids][]"]:checked')
      ).map(checkbox => parseInt(checkbox.value)).filter(id => !isNaN(id))
      
      // If no connectors selected, show the field (default state)
      if (checkedConnectorIds.length === 0) {
        this.show()
        return
      }
      
      // Check if any selected connector is NOT a file connector
      const hasNonFileConnector = checkedConnectorIds.some(id => {
        const connector = this.connectorsValue.find(c => c.id === id)
        return connector && !connector.is_file
      })
      
      if (hasNonFileConnector) {
        this.show()
      } else {
        this.hide()
      }
    } else {
      // No source type selected, show by default
      this.show()
    }
  }

  show() {
    this.element.classList.remove('hidden')
  }

  hide() {
    this.element.classList.add('hidden')
  }
}
