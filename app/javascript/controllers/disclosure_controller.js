import { Controller } from "@hotwired/stimulus"

// Disclosure controller for expanding/collapsing content sections
export default class extends Controller {
  static targets = ["content", "icon"]
  static values = { open: Boolean }

  connect() {
    this.update()
  }

  toggle() {
    this.openValue = !this.openValue
    this.update()
  }

  update() {
    if (this.openValue) {
      this.contentTarget.classList.remove("hidden")
      this.iconTarget.classList.add("rotate-180")
    } else {
      this.contentTarget.classList.add("hidden")
      this.iconTarget.classList.remove("rotate-180")
    }
  }
}
