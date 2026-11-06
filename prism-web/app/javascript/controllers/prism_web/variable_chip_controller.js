import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template"]

  connect() {
    this.variables = []
  }

  addVariable(name, type = "string", defaultValue = "") {
    const variable = { name, type, value: defaultValue }
    this.variables.push(variable)
    this.render()
  }

  removeVariable(name) {
    this.variables = this.variables.filter(v => v.name !== name)
    this.render()
  }

  updateVariable(name, value) {
    const variable = this.variables.find(v => v.name === name)
    if (variable) {
      variable.value = value
    }
  }

  render() {
    this.containerTarget.innerHTML = this.variables.map(variable => `
      <div class="variable-chip" data-variable-name="${variable.name}">
        <span class="variable-name">${variable.name}</span>
        <input type="${this.getInputType(variable.type)}" 
               value="${variable.value}"
               data-action="change->variable-chip#update">
        <button type="button" 
                data-action="click->variable-chip#remove">
          &times;
        </button>
      </div>
    `).join("")
  }

  getInputType(type) {
    switch (type) {
      case "integer": return "number"
      case "float": return "number"
      case "boolean": return "checkbox"
      case "date": return "date"
      case "datetime": return "datetime-local"
      default: return "text"
    }
  }

  update(event) {
    const input = event.target
    const name = input.closest("[data-variable-name]").dataset.variableName
    this.updateVariable(name, input.value)
  }

  remove(event) {
    const name = event.target.closest("[data-variable-name]").dataset.variableName
    this.removeVariable(name)
  }
}