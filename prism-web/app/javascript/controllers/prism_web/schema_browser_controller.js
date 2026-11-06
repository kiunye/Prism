import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tableList", "tableSchema"]

  loadTables() {
    const connectionSlug = this.element.dataset.connectionSlug
    fetch(`/prism/api/v1/connections/${connectionSlug}/schema`)
      .then(response => response.json())
      .then(data => {
        this.renderTableList(data.data)
      })
      .catch(error => {
        console.error("Failed to load tables:", error)
      })
  }

  loadTable(event) {
    const tableName = event.params.table
    const connectionSlug = this.element.dataset.connectionSlug
    fetch(`/prism/api/v1/connections/${connectionSlug}/tables/${tableName}`)
      .then(response => response.json())
      .then(data => {
        this.renderTableSchema(data.data)
      })
      .catch(error => {
        console.error("Failed to load table schema:", error)
      })
  }

  renderTableList(tables) {
    this.tableListTarget.innerHTML = tables.map(table => `
      <li>
        <button type="button" 
                data-action="click->schema-browser#loadTable"
                data-table="${table.name}">
          ${table.name}
        </button>
      </li>
    `).join("")
  }

  renderTableSchema(schema) {
    this.tableSchemaTarget.innerHTML = `
      <h3>${schema.name}</h3>
      <table class="table">
        <thead>
          <tr>
            <th>Column</th>
            <th>Type</th>
            <th>Nullable</th>
            <th>Default</th>
          </tr>
        </thead>
        <tbody>
          ${schema.columns.map(col => `
            <tr>
              <td>${col.name}</td>
              <td>${col.data_type}</td>
              <td>${col.nullable ? "Yes" : "No"}</td>
              <td>${col.default || ""}</td>
            </tr>
          `).join("")}
        </tbody>
      </table>
    `
  }
}