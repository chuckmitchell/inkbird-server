import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "celsius", "fahrenheit"]
  static values = {
    unit: { type: String, default: "C" },
    chartDataC: { type: Object, default: {} },
    chartDataF: { type: Object, default: {} }
  }

  connect() {
    const saved = this.getStoredUnit()
    if (saved && (saved === "C" || saved === "F")) {
      this.applyUnit(saved, false)
    } else {
      this.applyUnit(this.unitValue || "C", false)
    }
  }

  select(event) {
    const unit = event.currentTarget.dataset.unit
    if (unit && (unit === "C" || unit === "F")) {
      this.applyUnit(unit, true)
    }
  }

  applyUnit(unit, userInitiated = false) {
    this.unitValue = unit

    // Save choice to localStorage and 1-year cookie so browser remembers across reloads & server renders match
    try {
      localStorage.setItem("inkbird_temp_unit", unit)
    } catch (_) {}
    document.cookie = `inkbird_temp_unit=${unit}; path=/; max-age=31536000; SameSite=Lax`

    // Update toggle buttons in title bar
    this.buttonTargets.forEach(button => {
      const isActive = (button.dataset.unit === unit)
      button.setAttribute("aria-pressed", isActive ? "true" : "false")
      if (isActive) {
        button.className = "rounded-lg px-3 py-1.5 text-xs font-semibold transition cursor-pointer bg-sky-500 text-slate-950 shadow-sm"
      } else {
        button.className = "rounded-lg px-3 py-1.5 text-xs font-semibold transition cursor-pointer text-slate-400 hover:text-white"
      }
    })

    // Toggle Celsius and Fahrenheit elements
    this.celsiusTargets.forEach(el => {
      if (unit === "C") {
        el.classList.remove("hidden")
      } else {
        el.classList.add("hidden")
      }
    })

    this.fahrenheitTargets.forEach(el => {
      if (unit === "F") {
        el.classList.remove("hidden")
      } else {
        el.classList.add("hidden")
      }
    })

    // Update Chartkick chart
    this.updateChart(unit)
  }

  updateChart(unit) {
    const update = () => {
      if (typeof window !== "undefined" && window.Chartkick && window.Chartkick.charts) {
        const chart = window.Chartkick.charts["temperature-chart"]
        if (chart) {
          const data = (unit === "F") ? this.chartDataFValue : this.chartDataCValue
          if (data && Object.keys(data).length > 0) {
            const nextOptions = Object.assign({}, chart.options, {
              suffix: (unit === "F") ? "°F" : "°C"
            })
            chart.updateData(data, nextOptions)
            return true
          }
        }
      }
      return false
    }

    if (!update()) {
      setTimeout(update, 120)
    }
  }

  getStoredUnit() {
    try {
      const stored = localStorage.getItem("inkbird_temp_unit")
      if (stored === "C" || stored === "F") return stored
    } catch (_) {}

    const cookieMatch = document.cookie.match(/(?:^|;\s*)inkbird_temp_unit=(C|F)/)
    if (cookieMatch) {
      return cookieMatch[1]
    }

    return null
  }
}
