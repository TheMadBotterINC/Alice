import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "icon", "text", "spinner"]

  connect() {
    console.log("Test connection controller connected")
  }

  submit(event) {
    // Show spinner and disable button
    this.buttonTarget.disabled = true
    this.iconTarget.classList.add("hidden")
    this.spinnerTarget.classList.remove("hidden")
    this.textTarget.textContent = "Testing..."
    
    // Let the form submission proceed naturally
    // The page will redirect when the controller responds
  }
}
