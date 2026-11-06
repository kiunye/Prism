import { Application } from "@hotwired/stimulus"
import { definitionsFromContext } from "@hotwired/stimulus-loading"

const application = Application.start()
const context = require.context("./controllers", true, /\.js$/)
const definitions = definitionsFromContext(context)
application.load(definitions)

// Turbo Frame handlers
document.addEventListener("turbo:load", () => {
  const frames = document.querySelectorAll("turbo-frame")
  frames.forEach(frame => {
    frame.addEventListener("turbo:frame-load", () => {
      // Frame loaded event
    })
  })
})

export default application