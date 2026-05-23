import { Controller } from "@hotwired/stimulus"

console.log('Loading file connector mode controller')

// Connects to data-controller="file-connector-mode"
export default class extends Controller {
  static targets = ["modeOption", "filePathField"]
  
  connect() {
    console.log('File connector mode controller connected!')
    this.updateUI()
  }
  
  toggleMode(event) {
    this.updateUI()
  }
  
  updateUI() {
    // Get selected mode
    const selectedRadio = this.element.querySelector('input[name="connector[config][mode]"]:checked')
    const selectedMode = selectedRadio ? selectedRadio.value : 'file_path'
    
    // Update mode option styling
    this.modeOptionTargets.forEach(option => {
      const radio = option.querySelector('input[type="radio"]')
      const checkmark = option.querySelector('svg')
      
      if (radio && radio.value === selectedMode) {
        option.classList.add('border-primary', 'ring-2', 'ring-primary')
        option.classList.remove('border-gray-200')
        if (checkmark) checkmark.classList.remove('hidden')
      } else {
        option.classList.remove('border-primary', 'ring-2', 'ring-primary')
        option.classList.add('border-gray-200')
        if (checkmark) checkmark.classList.add('hidden')
      }
    })
    
    // Show/hide file path field based on mode
    if (this.hasFilePathFieldTarget) {
      if (selectedMode === 'file_path') {
        this.filePathFieldTarget.classList.remove('hidden')
        // Make file path required in file_path mode
        const input = this.filePathFieldTarget.querySelector('input[type="text"]')
        if (input) input.setAttribute('required', 'required')
      } else {
        this.filePathFieldTarget.classList.add('hidden')
        // Remove required in download mode
        const input = this.filePathFieldTarget.querySelector('input[type="text"]')
        if (input) input.removeAttribute('required')
      }
    }
  }
}
