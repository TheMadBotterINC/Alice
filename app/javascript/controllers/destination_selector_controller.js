import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="destination-selector"
export default class extends Controller {
  static targets = ["typeRadio", "datasetSection", "connectorSection", "fileExportSection"]

  connect() {
    // Initialize based on current selection
    this.switchType()
  }

  switchType() {
    const selectedType = this.typeRadioTargets.find(radio => radio.checked)?.value || 'none'
    
    // Hide all sections first
    this.datasetSectionTarget.classList.add('hidden')
    if (this.hasConnectorSectionTarget) {
      this.connectorSectionTarget.classList.add('hidden')
    }
    if (this.hasFileExportSectionTarget) {
      this.fileExportSectionTarget.classList.add('hidden')
    }
    
    // Clear the non-selected field values
    const datasetSelect = this.datasetSectionTarget.querySelector('select')
    const connectorSelect = this.hasConnectorSectionTarget ? this.connectorSectionTarget.querySelector('select') : null
    const exportFormatSelect = this.hasFileExportSectionTarget ? this.fileExportSectionTarget.querySelector('select[name="pipeline[export_format]"]') : null
    
    // Show and enable the selected section
    switch(selectedType) {
      case 'dataset':
        this.datasetSectionTarget.classList.remove('hidden')
        if (connectorSelect) connectorSelect.value = ''
        if (exportFormatSelect) exportFormatSelect.value = ''
        break
      case 'connector':
        if (this.hasConnectorSectionTarget) {
          this.connectorSectionTarget.classList.remove('hidden')
        }
        if (datasetSelect) datasetSelect.value = ''
        if (exportFormatSelect) exportFormatSelect.value = ''
        break
      case 'file_export':
        if (this.hasFileExportSectionTarget) {
          this.fileExportSectionTarget.classList.remove('hidden')
        }
        if (datasetSelect) datasetSelect.value = ''
        if (connectorSelect) connectorSelect.value = ''
        break
      case 'none':
        // All hidden, clear all values
        if (datasetSelect) datasetSelect.value = ''
        if (connectorSelect) connectorSelect.value = ''
        if (exportFormatSelect) exportFormatSelect.value = ''
        break
    }
  }
}
