import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="column-selection"
export default class extends Controller {
  static targets = ["checkbox", "count", "headerCheckbox"]
  
  connect() {
    this.updateCount()
  }
  
  selectAll() {
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = true
    })
    if (this.hasHeaderCheckboxTarget) {
      this.headerCheckboxTarget.checked = true
    }
    this.updateCount()
  }
  
  clearAll() {
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
    if (this.hasHeaderCheckboxTarget) {
      this.headerCheckboxTarget.checked = false
    }
    this.updateCount()
  }
  
  toggleAll(event) {
    const checked = event.target.checked
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = checked
    })
    this.updateCount()
  }
  
  updateCount() {
    const checkedCount = this.checkboxTargets.filter(cb => cb.checked).length
    if (this.hasCountTarget) {
      this.countTarget.textContent = checkedCount
    }
  }
}
