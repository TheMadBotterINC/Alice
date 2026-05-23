import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Bind validation method so it can be added/removed as event listener
    this.validateMergeKey = this.validateMergeKey.bind(this)
    
    // If merge is already selected on page load, set up validation
    const writeDispositionSelect = this.element.querySelector("select[name='pipeline[write_disposition]']")
    if (writeDispositionSelect && writeDispositionSelect.value === "merge") {
      this.setupMergeKeyValidation()
    }
  }

  toggleMergeKey(event) {
    const writeDisposition = event.target.value
    const mergeKeyField = document.getElementById("merge-key-field")
    
    if (writeDisposition === "merge") {
      mergeKeyField.classList.remove("hidden")
      this.setupMergeKeyValidation()
    } else {
      mergeKeyField.classList.add("hidden")
      this.removeMergeKeyValidation()
    }
  }

  setupMergeKeyValidation() {
    const mergeKeyInput = document.querySelector("input[name='pipeline[merge_key]']")
    if (mergeKeyInput) {
      // Add event listeners for real-time validation
      mergeKeyInput.addEventListener('blur', this.validateMergeKey)
      mergeKeyInput.addEventListener('input', this.validateMergeKey)
      
      // Run validation immediately if field already has content
      if (mergeKeyInput.value.trim() !== "") {
        this.validateMergeKey({ target: mergeKeyInput })
      }
    }
  }

  removeMergeKeyValidation() {
    const mergeKeyInput = document.querySelector("input[name='pipeline[merge_key]']")
    if (mergeKeyInput) {
      mergeKeyInput.removeEventListener('blur', this.validateMergeKey)
      mergeKeyInput.removeEventListener('input', this.validateMergeKey)
      // Clear any validation state
      this.clearValidationState(mergeKeyInput)
    }
  }

  validateMergeKey(event) {
    const input = event.target
    const value = input.value.trim()
    
    // Clear previous validation state
    this.clearValidationState(input)
    
    if (value === "") {
      // Show error state
      input.classList.add("border-red-500", "focus:border-red-500", "focus:ring-red-500")
      input.classList.remove("border-green-500", "focus:border-green-500", "focus:ring-green-500")
      this.showValidationMessage(input, "error", "⚠️ Merge key is required for merge disposition")
    } else {
      // Show success state
      input.classList.add("border-green-500", "focus:border-green-500", "focus:ring-green-500")
      input.classList.remove("border-red-500", "focus:border-red-500", "focus:ring-red-500")
      this.showValidationMessage(input, "success", "✓ Valid merge key")
    }
  }

  clearValidationState(input) {
    input.classList.remove(
      "border-red-500", "focus:border-red-500", "focus:ring-red-500",
      "border-green-500", "focus:border-green-500", "focus:ring-green-500"
    )
    this.removeValidationMessage(input)
  }

  showValidationMessage(input, type, message) {
    // Remove any existing validation message
    this.removeValidationMessage(input)
    
    // Create validation message element
    const messageDiv = document.createElement("div")
    messageDiv.classList.add("merge-key-validation-message", "mt-1", "text-sm", "font-medium")
    
    if (type === "error") {
      messageDiv.classList.add("text-red-600")
      // Hide help text when showing error
      this.toggleHelpText(false)
    } else {
      messageDiv.classList.add("text-green-600")
      // Show help text when showing success
      this.toggleHelpText(true)
    }
    
    messageDiv.textContent = message
    
    // Insert after the input wrapper
    input.parentElement.appendChild(messageDiv)
  }

  removeValidationMessage(input) {
    const existingMessage = input.parentElement.querySelector(".merge-key-validation-message")
    if (existingMessage) {
      existingMessage.remove()
    }
    // Always show help text when clearing validation
    this.toggleHelpText(true)
  }

  toggleHelpText(show) {
    const helpText = document.querySelector(".merge-key-help-text")
    if (helpText) {
      if (show) {
        helpText.classList.remove("hidden")
      } else {
        helpText.classList.add("hidden")
      }
    }
  }
}
