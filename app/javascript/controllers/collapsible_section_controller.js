import { Controller } from "@hotwired/stimulus"

// Collapsible Section Controller
// Makes any section collapsible with smooth animation and state persistence
export default class extends Controller {
  static targets = ["content", "toggleIcon"]
  static values = {
    storageKey: String,
    defaultExpanded: { type: Boolean, default: false }
  }

  connect() {
    console.log("Collapsible Section connected", this.storageKeyValue)
    
    // Load saved state from sessionStorage
    const savedState = this.loadState()
    const isExpanded = savedState !== null ? savedState : this.defaultExpandedValue
    
    // Set initial state without animation
    this.setExpandedState(isExpanded, false)
  }

  toggle() {
    const isCurrentlyExpanded = this.isExpanded()
    this.setExpandedState(!isCurrentlyExpanded, true)
    this.saveState(!isCurrentlyExpanded)
  }

  expand() {
    if (!this.isExpanded()) {
      this.setExpandedState(true, true)
      this.saveState(true)
    }
  }

  collapse() {
    if (this.isExpanded()) {
      this.setExpandedState(false, true)
      this.saveState(false)
    }
  }

  isExpanded() {
    return !this.contentTarget.classList.contains("hidden")
  }

  setExpandedState(expanded, animate = true) {
    if (expanded) {
      // Expanding
      this.contentTarget.classList.remove("hidden")
      
      if (animate) {
        // Animate max-height for smooth expand
        this.contentTarget.style.maxHeight = "0px"
        this.contentTarget.style.overflow = "hidden"
        this.contentTarget.style.transition = "max-height 0.3s ease-in-out"
        
        // Force reflow
        this.contentTarget.offsetHeight
        
        // Use a timeout to measure height after any rendering has occurred
        requestAnimationFrame(() => {
          // Set to scrollHeight for expansion
          this.contentTarget.style.maxHeight = this.contentTarget.scrollHeight + "px"
          
          // Remove max-height after animation completes
          setTimeout(() => {
            this.contentTarget.style.maxHeight = "none"
            this.contentTarget.style.overflow = "visible"
          }, 300)
        })
      }
      
      // Update icon rotation
      if (this.hasToggleIconTarget) {
        this.toggleIconTarget.style.transform = "rotate(180deg)"
      }
      
      // Update ARIA state
      this.element.setAttribute("aria-expanded", "true")
    } else {
      // Collapsing
      if (animate) {
        // Set current height first
        this.contentTarget.style.maxHeight = this.contentTarget.scrollHeight + "px"
        this.contentTarget.style.overflow = "hidden"
        this.contentTarget.style.transition = "max-height 0.3s ease-in-out"
        
        // Force reflow
        this.contentTarget.offsetHeight
        
        // Collapse to 0
        this.contentTarget.style.maxHeight = "0px"
        
        // Hide after animation
        setTimeout(() => {
          this.contentTarget.classList.add("hidden")
          this.contentTarget.style.maxHeight = "none"
          this.contentTarget.style.overflow = "visible"
        }, 300)
      } else {
        this.contentTarget.classList.add("hidden")
      }
      
      // Update icon rotation
      if (this.hasToggleIconTarget) {
        this.toggleIconTarget.style.transform = "rotate(0deg)"
      }
      
      // Update ARIA state
      this.element.setAttribute("aria-expanded", "false")
    }
  }

  loadState() {
    if (!this.storageKeyValue) return null
    
    const saved = sessionStorage.getItem(this.storageKeyValue)
    return saved !== null ? saved === "true" : null
  }

  saveState(expanded) {
    if (!this.storageKeyValue) return
    
    sessionStorage.setItem(this.storageKeyValue, expanded.toString())
  }
}
