import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="modal"
export default class extends Controller {
  static targets = ["container", "backdrop"]

  connect() {
    // Close modal on escape key
    this.escapeHandler = (e) => {
      if (e.key === "Escape" && this.isOpen()) {
        this.close()
      }
    }
    document.addEventListener("keydown", this.escapeHandler)
  }

  disconnect() {
    document.removeEventListener("keydown", this.escapeHandler)
    document.body.classList.remove("overflow-hidden")
  }

  open() {
    this.element.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
    
    // Focus the first focusable element in the modal
    setTimeout(() => {
      const focusable = this.containerTarget.querySelector('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])')
      if (focusable) focusable.focus()
    }, 100)
  }

  close() {
    this.element.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  isOpen() {
    return !this.element.classList.contains("hidden")
  }

  // Close when clicking on backdrop
  closeOnBackdrop(event) {
    if (event.target === this.backdropTarget || event.target === this.element) {
      this.close()
    }
  }

  // Prevent closing when clicking inside modal content
  preventClose(event) {
    event.stopPropagation()
  }
}
