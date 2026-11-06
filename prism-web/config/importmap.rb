# Importmap for PrismWeb
#
# This file configures the importmap for the PrismWeb engine.
# In the host app, this will be merged with the host app's importmap.

pin_all_from "app/javascript/controllers/prism_web", under: "prism_web/controllers"

pin "prism_web/application", to: "prism_web/application.js"

# CDN Libraries
pin "codemirror", to: "https://cdn.jsdelivr.net/npm/codemirror@6.0.0/+esm"
pin "@codemirror/state", to: "https://cdn.jsdelivr.net/npm/@codemirror/state@6.4.1/+esm"
pin "@codemirror/view", to: "https://cdn.jsdelivr.net/npm/@codemirror/view@6.29.0/+esm"
pin "@codemirror/language", to: "https://cdn.jsdelivr.net/npm/@codemirror/language@6.10.1/+esm"
pin "@codemirror/commands", to: "https://cdn.jsdelivr.net/npm/@codemirror/commands@6.6.0/+esm"
pin "@codemirror/autocomplete", to: "https://cdn.jsdelivr.net/npm/@codemirror/autocomplete@6.18.0/+esm"
pin "@codemirror/lint", to: "https://cdn.jsdelivr.net/npm/@codemirror/lint@6.8.0/+esm"
pin "@codemirror/lang-sql", to: "https://cdn.jsdelivr.net/npm/@codemirror/lang-sql@6.7.0/+esm"
pin "@lezer/common", to: "https://cdn.jsdelivr.net/npm/@lezer/common@1.2.1/+esm"
pin "@lezer/highlight", to: "https://cdn.jsdelivr.net/npm/@lezer/highlight@1.2.1/+esm"
pin "@lezer/lr", to: "https://cdn.jsdelivr.net/npm/@lezer/lr@1.4.1/+esm"
pin "apexcharts", to: "https://cdn.jsdelivr.net/npm/apexcharts@3.41.0/dist/apexcharts.min.js"
pin "gridstack", to: "https://cdn.jsdelivr.net/npm/gridstack@10.0.0/dist/gridstack-all.js"

# Stimulus
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin_all_from "app/javascript/controllers", under: "controllers"