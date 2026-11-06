import { Controller } from "@hotwired/stimulus"
import { EditorState, EditorView, lineNumbers, highlightActiveLine } from "@codemirror/view"
import { EditorState as EditorState2, Compartment } from "@codemirror/state"
import { sql } from "@codemirror/lang-sql"
import { defaultKeymap, historyKeymap, history } from "@codemirror/commands"
import { linter, lintGutter, setDiagnostics, forEachDiagnostic } from "@codemirror/lint"

export default class extends Controller {
  static targets = ["editor", "variables", "results", "errors", "explain"]

  connect() {
    this.initializeEditor()
  }

  initializeEditor() {
    const host = this.editorTarget

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    this.csrfToken = csrfToken

    const validateLinter = linter(async (view) => {
      const sql = view.state.doc.toString()
      if (!sql.trim()) return []

      try {
        const response = await fetch("/prism/api/v1/queries/validate", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            "X-CSRF-Token": this.csrfToken
          },
          body: JSON.stringify({ query: sql, variables: this.collectVariables() })
        })
        const envelope = await response.json()
        return this.toDiagnostics(envelope, view)
      } catch (error) {
        console.error("Validation failed:", error)
        return []
      }
    }, { delay: 500 })

    this.editorView = new EditorView({
      state: EditorState2.create({
        doc: "",
        extensions: [
          history(),
          lineNumbers(),
          lintGutter(),
          highlightActiveLine(),
          sql(),
          validateLinter,
          EditorView.lineWrapping,
          EditorState2.tabSize.of(2),
          EditorView.theme({
            "&": { height: "400px", fontSize: "13px" },
            ".cm-scroller": { fontFamily: "monospace" }
          }),
          EditorView.updateListener.of((update) => {
            if (update.docChanged) this.updateVariables()
          }),
          EditorView.domEventHandlers({
            keydown: (event) => this.handleKeydown(event)
          })
        ]
      }),
      parent: host
    })
  }

  handleKeydown(event) {
    if (event.ctrlKey || event.metaKey) {
      if (event.key === "Enter") {
        event.preventDefault()
        this.executeQuery()
        return true
      }
      if (event.key === "s" || event.key === "S") {
        event.preventDefault()
        this.validateQuery()
        return true
      }
    }
    return false
  }

  getEditorDoc() {
    return this.editorView?.state.doc.toString() || ""
  }

  updateVariables() {
    const sql = this.getEditorDoc()
    const variables = this.extractVariables(sql)
    this.renderVariables(variables)
  }

  extractVariables(sql) {
    const regex = /\{\{(\w+)\}\}/g
    const matches = []
    let match
    while ((match = regex.exec(sql)) !== null) {
      matches.push({ name: match[1], value: "" })
    }
    return matches
  }

  renderVariables(variables) {
    if (variables.length === 0) {
      this.variablesTarget.style.display = "none"
      return
    }

    this.variablesTarget.style.display = "block"
    this.variablesTarget.innerHTML = variables.map(variable => `
      <div class="variable-chip">
        <label>${variable.name}</label>
        <input type="text"
               data-action="change->sql-editor#collectVariables"
               data-variable-name="${variable.name}"
               value="${variable.value}">
      </div>
    `).join("")
  }

  validateQuery() {
    const sql = this.getEditorDoc()
    if (!sql.trim()) return

    fetch("/prism/api/v1/queries/validate", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": this.csrfToken
      },
      body: JSON.stringify({ query: sql, variables: this.collectVariables() })
    })
      .then(response => response.json())
      .then(envelope => {
        this.applyDiagnostics(envelope)
        this.renderValidationSummary(envelope)
      })
      .catch(error => console.error("Validation failed:", error))
  }

  toDiagnostics(envelope, view) {
    const errors = (envelope?.data?.errors) || []
    const warnings = (envelope?.data?.warnings) || []
    const diags = []
    const state = view.state

    errors.forEach((err) => {
      const pos = this.resolvePosition(state, err)
      diags.push({
        from: pos.from,
        to: pos.to,
        severity: "error",
        message: err.message || err.text || String(err)
      })
    })

    warnings.forEach((warn) => {
      const pos = this.resolvePosition(state, warn)
      diags.push({
        from: pos.from,
        to: pos.to,
        severity: "warning",
        message: warn.message || warn.text || String(warn)
      })
    })

    return diags
  }

  applyDiagnostics(envelope) {
    if (!this.editorView) return
    const diags = this.toDiagnostics(envelope, this.editorView)
    this.editorView.dispatch(setDiagnostics(this.editorView.state, diags))
  }

  renderValidationSummary(envelope) {
    const errorCount = (envelope?.data?.errors || []).length
    if (errorCount > 0) {
      this.errorsTarget.innerHTML = `<div class="error">${errorCount} validation error(s) shown inline in the editor.</div>`
      this.errorsTarget.style.display = "block"
    } else {
      this.errorsTarget.style.display = "none"
    }
  }

  resolvePosition(state, err) {
    const line = err && (err.line || err.location?.line)
    const column = err && (err.column || err.character || err.location?.column)
    if (line && column) {
      const linePos = state.doc.line(Math.max(1, line))
      const from = Math.min(linePos.from + Math.max(0, column - 1), linePos.to)
      const to = Math.min(from + 1, linePos.to)
      return { from, to }
    }
    if (err && err.offset) {
      const from = Math.min(err.offset, state.doc.length)
      return { from, to: Math.min(from + 1, state.doc.length) }
    }
    const cursor = state.selection.main.head
    return { from: cursor, to: Math.min(cursor + 1, state.doc.length) }
  }

  executeQuery() {
    const sql = this.getEditorDoc()
    const variables = this.collectVariables()

    fetch("/prism/api/v1/queries/execute", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": this.csrfToken
      },
      body: JSON.stringify({ query: sql, variables: variables })
    })
      .then(response => response.json())
      .then(data => this.showResults(data))
      .catch(error => console.error("Execution failed:", error))
  }

  explainQuery() {
    const sql = this.getEditorDoc()
    const variables = this.collectVariables()

    fetch("/prism/api/v1/queries/explain", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": this.csrfToken
      },
      body: JSON.stringify({ query: sql, variables: variables })
    })
      .then(response => response.json())
      .then(data => this.showExplain(data))
      .catch(error => console.error("Explain failed:", error))
  }

  exportCsv() {
    const sql = this.getEditorDoc()
    const variables = this.collectVariables()

    fetch("/prism/api/v1/queries/execute", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "text/csv",
        "X-CSRF-Token": this.csrfToken
      },
      body: JSON.stringify({ query: sql, variables: variables })
    })
      .then(response => {
        const disposition = response.headers.get("Content-Disposition") || ""
        const match = disposition.match(/filename="(.+)"/)
        const filename = match ? match[1] : "query_export.csv"
        return response.blob().then(blob => ({ blob, filename }))
      })
      .then(({ blob, filename }) => {
        const url = URL.createObjectURL(blob)
        const a = document.createElement("a")
        a.href = url
        a.download = filename
        document.body.appendChild(a)
        a.click()
        document.body.removeChild(a)
        URL.revokeObjectURL(url)
      })
      .catch(error => console.error("CSV export failed:", error))
  }

  collectVariables() {
    if (!this.hasVariablesTarget) return {}
    const variableInputs = this.variablesTarget.querySelectorAll("input[data-variable-name]")
    const variables = {}
    variableInputs.forEach(input => {
      variables[input.dataset.variableName] = input.value
    })
    return variables
  }

  showResults(data) {
    this.resultsTarget.style.display = "block"
    this.resultsTarget.innerHTML = `
      <div class="results">
        <div class="meta">
          <span>Rows: ${data.meta?.row_count || 0}</span>
          <span>Time: ${data.meta?.duration_ms || 0}ms</span>
        </div>
        <table class="table">
          <thead>
            <tr>${data.data?.columns?.map(col => `<th>${col}</th>`).join("") || ""}</tr>
          </thead>
          <tbody>
            ${data.data?.rows?.map(row => `<tr>${row.map(cell => `<td>${cell}</td>`).join("")}</tr>`).join("") || ""}
          </tbody>
        </table>
      </div>
    `
  }

  showExplain(data) {
    this.explainTarget.style.display = "block"
    this.explainTarget.innerHTML = `
      <div class="explain">
        <div class="meta">
          <span>Estimated Cost: ${data.data?.estimated_cost || "N/A"}</span>
        </div>
        <pre>${JSON.stringify(data.data?.plan_json, null, 2)}</pre>
      </div>
    `
  }
}
