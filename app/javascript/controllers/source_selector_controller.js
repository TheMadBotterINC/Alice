import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="source-selector"
export default class extends Controller {
  static targets = ["typeRadio", "connectorsSection", "datasetsSection"]

  connect() {
    this.updateVisibility()
  }

  switchType(event) {
    this.updateVisibility()
  }

  updateVisibility() {
    const selectedType = this.typeRadioTargets.find(radio => radio.checked)?.value

    if (selectedType === "connectors") {
      this.showConnectors()
      this.clearDatasets()
    } else if (selectedType === "datasets") {
      this.showDatasets()
      this.clearConnectors()
    }
  }

  showConnectors() {
    this.connectorsSectionTarget.classList.remove("hidden")
    this.datasetsSectionTarget.classList.add("hidden")
  }

  showDatasets() {
    this.datasetsSectionTarget.classList.remove("hidden")
    this.connectorsSectionTarget.classList.add("hidden")
  }

  clearConnectors() {
    // Uncheck all connector checkboxes
    const checkboxes = this.connectorsSectionTarget.querySelectorAll('input[type="checkbox"]')
    checkboxes.forEach(checkbox => {
      checkbox.checked = false
    })
  }

  clearDatasets() {
    // Uncheck all dataset checkboxes
    const checkboxes = this.datasetsSectionTarget.querySelectorAll('input[type="checkbox"]')
    checkboxes.forEach(checkbox => {
      checkbox.checked = false
    })
  }
}
