import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["grid", "addWidget"]

  connect() {
    this.initializeGrid()
  }

  initializeGrid() {
    // GridStack initialization
    this.grid = window.GridStack.init(this.gridTarget, {
      animation: true,
      dragDisable: false,
      resizable: {
        handles: "e,se,s,sw,w,ne,nw"
      }
    })

    this.grid.on("added removed", () => {
      this.saveLayout()
    })
  }

  saveLayout() {
    const layout = this.grid.save()
    const dashboardId = this.element.dataset.dashboardId

    fetch(`/prism/api/v1/dashboards/${dashboardId}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
      },
      body: JSON.stringify({ dashboard: { grid_layout: layout } })
    })
      .then(response => response.json())
      .then(data => {
        console.log("Layout saved:", data)
      })
      .catch(error => {
        console.error("Failed to save layout:", error)
      })
  }

  addWidget(event) {
    event.preventDefault()

    const dashboardId = this.element.dataset.dashboardId
    const formData = new FormData(event.target)

    fetch(`/prism/api/v1/dashboards/${dashboardId}/widgets`, {
      method: "POST",
      headers: {
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
      },
      body: formData
    })
      .then(response => response.json())
      .then(data => {
        this.addWidgetToGrid(data.data)
      })
      .catch(error => {
        console.error("Failed to add widget:", error)
      })
  }

  addWidgetToGrid(widget) {
    this.grid.addWidget({
      id: `widget-${widget.id}`,
      x: 0,
      y: 0,
      w: 4,
      h: 4,
      content: `<div class="widget" data-widget-id="${widget.id}">
        <div id="chart-${widget.id}"></div>
      </div>`
    })
  }
}