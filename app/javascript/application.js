// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "chartkick"
import "Chart.bundle"

const freezingLinePlugin = {
  id: "freezingLine",
  beforeDatasetsDraw(chart, _args, pluginOptions) {
    if (!pluginOptions || !pluginOptions.enabled) return

    const yScale = chart.scales && chart.scales.y
    const chartArea = chart.chartArea
    if (!yScale || !chartArea) return

    const value = (typeof pluginOptions.value === "number") ? pluginOptions.value : 32
    const yPixel = yScale.getPixelForValue(value)
    if (yPixel < chartArea.top || yPixel > chartArea.bottom) return

    const ctx = chart.ctx
    ctx.save()
    ctx.beginPath()
    ctx.strokeStyle = pluginOptions.color || "#ef4444"
    ctx.lineWidth = pluginOptions.lineWidth || 1
    ctx.moveTo(chartArea.left, yPixel)
    ctx.lineTo(chartArea.right, yPixel)
    ctx.stroke()
    ctx.restore()
  }
}

if (typeof window !== "undefined" && window.Chart && typeof window.Chart.register === "function") {
  window.Chart.register(freezingLinePlugin)
}

