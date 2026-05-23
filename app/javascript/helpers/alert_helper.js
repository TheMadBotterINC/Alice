// Global alert helper function
// Usage: window.showAlert('Title', 'Message', 'error')

export function showAlert(title, message, type = 'info') {
  // Find the alert-modal controller
  const alertElement = document.querySelector('[data-controller~="alert-modal"]')
  if (!alertElement) {
    console.error('Alert modal not found in the DOM')
    // Fallback to native alert
    alert(`${title}\n\n${message}`)
    return
  }
  
  // Get the Stimulus controller instance
  const alertController = window.Stimulus.getControllerForElementAndIdentifier(
    alertElement,
    'alert-modal'
  )
  
  if (alertController) {
    alertController.show(title, message, type)
  } else {
    console.error('Alert modal controller not initialized')
    alert(`${title}\n\n${message}`)
  }
}

// Make it globally available
window.showAlert = showAlert

// Convenience functions
window.showError = (title, message) => showAlert(title, message, 'error')
window.showSuccess = (title, message) => showAlert(title, message, 'success')
window.showWarning = (title, message) => showAlert(title, message, 'warning')
window.showInfo = (title, message) => showAlert(title, message, 'info')
