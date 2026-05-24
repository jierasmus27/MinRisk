import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["progress", "actions", "message"]
  static values = {
    statusUrl: String,
    polling: { type: Boolean, default: false }
  }

  connect() {
    if (this.pollingValue) this.startPolling()
  }

  disconnect() {
    this.stopPolling()
  }

  submitStart() {
    this.showProgress("Committing import…")
    this.disableActions()
  }

  startPolling() {
    if (this.pollTimer) return

    this.showProgress("Committing import…")
    this.disableActions()
    this.pollTimer = window.setInterval(() => this.checkStatus(), 1000)
    this.checkStatus()
  }

  stopPolling() {
    if (!this.pollTimer) return

    window.clearInterval(this.pollTimer)
    this.pollTimer = null
  }

  async checkStatus() {
    if (!this.hasStatusUrlValue) return

    try {
      const response = await fetch(this.statusUrlValue, {
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      })

      if (!response.ok) return

      const data = await response.json()
      if (!data.finished) return

      this.stopPolling()

      if (data.status === "committed") {
        Turbo.visit(window.location.href, { action: "replace" })
        return
      }

      if (data.commit_error) {
        this.showProgress(data.commit_error, true)
        window.setTimeout(() => Turbo.visit(window.location.href, { action: "replace" }), 2000)
      }
    } catch (_error) {
      // Keep polling through transient network errors.
    }
  }

  showProgress(message, isError = false) {
    if (this.hasProgressTarget) this.progressTarget.classList.remove("hidden")
    if (this.hasActionsTarget) this.actionsTarget.classList.add("hidden")
    if (this.hasMessageTarget) {
      this.messageTarget.textContent = message
      this.messageTarget.classList.toggle("text-error", isError)
      this.messageTarget.classList.toggle("text-on-surface-variant", !isError)
    }
  }

  disableActions() {
    if (!this.hasActionsTarget) return

    this.actionsTarget.querySelectorAll("button, input[type='submit']").forEach((element) => {
      element.disabled = true
      element.classList.add("opacity-50", "cursor-not-allowed")
    })
  }
}
