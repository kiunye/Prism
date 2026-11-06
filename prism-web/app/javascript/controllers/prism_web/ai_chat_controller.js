import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "input", "sendButton"]

  connect() {
    this.conversationId = this.element.dataset.conversationId
  }

  sendMessage(event) {
    event.preventDefault()

    const message = this.inputTarget.value.trim()
    if (!message) return

    this.inputTarget.value = ""
    this.addMessage(message, "user")

    this.sendButtonTarget.disabled = true
    this.sendButtonTarget.textContent = "Thinking..."

    fetch(`/prism/api/v1/ai_conversations/${this.conversationId}/messages`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
      },
      body: JSON.stringify({ message: message })
    })
      .then(response => response.json())
      .then(data => {
        this.addMessage(data.data.response, "ai")
        this.sendButtonTarget.disabled = false
        this.sendButtonTarget.textContent = "Send"
      })
      .catch(error => {
        console.error("AI request failed:", error)
        this.sendButtonTarget.disabled = false
        this.sendButtonTarget.textContent = "Send"
      })
  }

  addMessage(text, sender) {
    const messageDiv = document.createElement("div")
    messageDiv.className = `message ${sender}-message`
    messageDiv.innerHTML = `
      <div class="message-sender">${sender === "user" ? "You" : "Prism AI"}</div>
      <div class="message-content">${text}</div>
    `
    this.messagesTarget.appendChild(messageDiv)
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }
}