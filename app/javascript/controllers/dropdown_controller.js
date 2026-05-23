import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dropdown"
export default class extends Controller {
  static targets = ["menu"]

  connect() {
    // Close dropdown when clicking outside
    this.clickOutsideHandler = this.handleClickOutside.bind(this)
    document.addEventListener("click", this.clickOutsideHandler)

    // Close dropdown on escape key
    this.escapeHandler = this.close.bind(this)
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && this.isOpen()) {
        this.close()
      }
    })
  }

  disconnect() {
    document.removeEventListener("click", this.clickOutsideHandler)
    document.removeEventListener("keydown", this.escapeHandler)
  }

  toggle(event) {
    event.stopPropagation()
    if (this.isOpen()) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.menuTarget.classList.remove("hidden")
  }

  close() {
    this.menuTarget.classList.add("hidden")
  }

  isOpen() {
    return !this.menuTarget.classList.contains("hidden")
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target) && this.isOpen()) {
      this.close()
    }
  }
}
