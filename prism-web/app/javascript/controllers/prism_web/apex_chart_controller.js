import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chart", "loading"]
  static values = { 
    type: String, 
    widgetId: String,
    refreshInterval: Number 
  }

  connect() {
    this.chart = null
    this.loadData()
  }

  loadData() {
    this.loadingTarget.style.display = "block"

    fetch(`/prism/api/v1/dashboards/widgets/${this.widgetIdValue}/data`)
      .then(response => response.json())
      .then(data => {
        this.renderChart(data)
        this.loadingTarget.style.display = "none"
      })
      .catch(error => {
        console.error("Failed to load widget data:", error)
        this.loadingTarget.style.display = "none"
      })
  }

  renderChart(data) {
    if (this.chart) {
      this.chart.updateOptions({
        series: data.series || [],
        xaxis: { categories: data.categories || [] }
      })
      return
    }

    this.chart = new window.ApexCharts(this.chartTarget, {
      chart: {
        type: this.typeValue || "line",
        height: 350,
        toolbar: { show: false }
      },
      series: data.series || [],
      xaxis: {
        categories: data.categories || []
      },
      stroke: {
        curve: "smooth"
      },
      markers: {
        size: 4
      },
      responsive: [{
        breakpoint: 480,
        options: {
          chart: {
            width: 100
          }
        }
      }]
    })

    this.chart.render()

    if (this.refreshIntervalValue && this.refreshIntervalValue > 0) {
      setInterval(() => this.loadData(), this.refreshIntervalValue * 1000)
    }
  }

  refresh() {
    this.loadData()
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }
}