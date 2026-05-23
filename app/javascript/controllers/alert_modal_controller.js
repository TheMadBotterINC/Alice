import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="alert-modal"
export default class extends Controller {
  static targets = ["modal", "title", "message", "icon"]
  static values = {
    type: { type: String, default: "info" } // info, success, warning, error
  }
  
  connect() {
    console.log('Alert modal controller connected')
  }
  
  show(title, message, type = "info") {
    this.typeValue = type
    this.titleTarget.textContent = title
    this.messageTarget.textContent = message
    
    // Update icon and colors based on type
    this.updateAppearance()
    
    // Show modal
    this.modalTarget.classList.remove('hidden')
    
    // Auto-hide after 5 seconds for success messages
    if (type === 'success') {
      setTimeout(() => this.hide(), 5000)
    }
  }
  
  hide() {
    this.modalTarget.classList.add('hidden')
  }
  
  updateAppearance() {
    const iconTarget = this.iconTarget
    const type = this.typeValue
    
    // Clear existing classes
    iconTarget.className = 'mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full sm:mx-0 sm:h-10 sm:w-10'
    
    // Add type-specific classes and icon
    switch(type) {
      case 'success':
        iconTarget.classList.add('bg-green-100')
        iconTarget.innerHTML = `
          <svg class="h-6 w-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
          </svg>
        `
        break
      case 'error':
        iconTarget.classList.add('bg-red-100')
        iconTarget.innerHTML = `
          <svg class="h-6 w-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        `
        break
      case 'warning':
        iconTarget.classList.add('bg-yellow-100')
        iconTarget.innerHTML = `
          <svg class="h-6 w-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>
          </svg>
        `
        break
      default: // info
        iconTarget.classList.add('bg-blue-100')
        iconTarget.innerHTML = `
          <svg class="h-6 w-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
        `
    }
  }
  
  // Handle backdrop click
  closeOnBackdrop(event) {
    if (event.target === event.currentTarget) {
      this.hide()
    }
  }
}
