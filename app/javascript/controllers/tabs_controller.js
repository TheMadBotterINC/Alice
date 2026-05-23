import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tabs"
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { defaultTab: String }

  connect() {
    // Show default tab or first tab
    const defaultTab = this.defaultTabValue || this.tabTargets[0]?.dataset.tab
    if (defaultTab) {
      this.show(defaultTab)
    }
  }

  switch(event) {
    event.preventDefault()
    const tab = event.currentTarget.dataset.tab
    this.show(tab)
  }

  show(tabName) {
    // Update tab buttons
    this.tabTargets.forEach(tab => {
      if (tab.dataset.tab === tabName) {
        tab.classList.add("border-primary", "text-primary")
        tab.classList.remove("border-transparent", "text-gray-500", "hover:text-gray-700", "hover:border-gray-300")
        tab.setAttribute("aria-selected", "true")
      } else {
        tab.classList.remove("border-primary", "text-primary")
        tab.classList.add("border-transparent", "text-gray-500", "hover:text-gray-700", "hover:border-gray-300")
        tab.setAttribute("aria-selected", "false")
      }
    })

    // Update panels
    this.panelTargets.forEach(panel => {
      if (panel.dataset.tab === tabName) {
        panel.classList.remove("hidden")
      } else {
        panel.classList.add("hidden")
      }
    })

    // Update URL hash (optional)
    if (window.history.replaceState) {
      window.history.replaceState(null, null, `#${tabName}`)
    }
  }
}
