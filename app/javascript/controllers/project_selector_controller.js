import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Navigates to the selected project's Scope & Inputs page.
export default class extends Controller {
  visit(event) {
    const url = event.target.value
    if (url && url !== window.location.pathname) {
      Turbo.visit(url)
    }
  }
}
