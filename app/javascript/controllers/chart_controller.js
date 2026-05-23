import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    type: String,
    data: Object,
    options: Object
  }

  connect() {
    // Wait for Chart.js to be fully loaded (it's loaded via script tag in layout)
    this.waitForChart()
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }

  waitForChart() {
    if (typeof window.Chart !== 'undefined') {
      this.initializeChart()
    } else {
      // Chart.js not ready yet, check again in 50ms
      setTimeout(() => this.waitForChart(), 50)
    }
  }

  initializeChart() {
    try {
      const ctx = this.element.getContext('2d')
      
      if (!ctx) {
        console.error('Could not get canvas context')
        return
      }
      
      const defaultOptions = {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'bottom',
          }
        }
      }

      const options = { ...defaultOptions, ...this.optionsValue }

      this.chart = new window.Chart(ctx, {
        type: this.typeValue,
        data: this.dataValue,
        options: options
      })
    } catch (error) {
      console.error('Error creating chart:', error)
    }
  }
}
