import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sidebar"
export default class extends Controller {
  static targets = ["menu", "backdrop", "desktop", "text", "toggleBtn", "icon"]
  
  connect() {
    // Close sidebar on escape key
    this.escapeHandler = this.close.bind(this)
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && this.isOpen()) {
        this.close()
      }
    })
    
    // Restore collapsed state from localStorage
    const isCollapsed = localStorage.getItem('sidebarCollapsed') === 'true'
    if (isCollapsed) {
      this.collapse(false) // false = don't save to localStorage again
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.escapeHandler)
  }

  toggle() {
    if (this.isOpen()) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.menuTarget.classList.remove("-translate-x-full")
    this.backdropTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
  }

  close() {
    this.menuTarget.classList.add("-translate-x-full")
    this.backdropTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  isOpen() {
    return !this.menuTarget.classList.contains("-translate-x-full")
  }

  // Close when clicking outside (on backdrop)
  closeOnBackdrop(event) {
    if (event.target === this.backdropTarget) {
      this.close()
    }
  }
  
  // Toggle collapsed state (desktop only)
  toggleCollapse() {
    if (this.isCollapsed()) {
      this.expand()
    } else {
      this.collapse()
    }
  }
  
  collapse(save = true) {
    this.desktopTarget.classList.remove('w-64')
    this.desktopTarget.classList.add('w-16')
    this.textTargets.forEach(el => el.classList.add('hidden'))
    // Remove icon margin and center nav items when collapsed
    this.element.querySelectorAll('nav a').forEach(link => {
      link.classList.add('justify-center')
      link.classList.remove('px-4')
      link.classList.add('px-2')
      link.classList.remove('py-3')
      link.classList.add('py-2')
    })
    this.element.querySelectorAll('nav svg').forEach(svg => {
      svg.classList.remove('mr-3')
    })
    // Flip chevron to point right
    if (this.hasToggleBtnTarget) {
      this.toggleBtnTarget.querySelector('svg path').setAttribute('d', 'M13 5l7 7-7 7M6 5l7 7-7 7')
    }
    if (save) {
      localStorage.setItem('sidebarCollapsed', 'true')
    }
  }
  
  expand(save = true) {
    this.desktopTarget.classList.remove('w-16')
    this.desktopTarget.classList.add('w-64')
    this.textTargets.forEach(el => el.classList.remove('hidden'))
    // Restore icon margin and left-align nav items when expanded
    this.element.querySelectorAll('nav a').forEach(link => {
      link.classList.remove('justify-center')
      link.classList.remove('px-2')
      link.classList.add('px-4')
      link.classList.remove('py-2')
      link.classList.add('py-3')
    })
    this.element.querySelectorAll('nav svg').forEach(svg => {
      if (!svg.closest('button[data-sidebar-target="toggleBtn"]')) {
        svg.classList.add('mr-3')
      }
    })
    // Flip chevron to point left
    if (this.hasToggleBtnTarget) {
      this.toggleBtnTarget.querySelector('svg path').setAttribute('d', 'M11 19l-7-7 7-7m8 14l-7-7 7-7')
    }
    if (save) {
      localStorage.setItem('sidebarCollapsed', 'false')
    }
  }
  
  isCollapsed() {
    return this.desktopTarget.classList.contains('w-16')
  }
}
