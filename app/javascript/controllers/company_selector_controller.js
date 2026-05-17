import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "newPanel"]

  connect() {
    this.toggle()
  }

  toggle() {
    const showNew = this.selectTarget.value === "new"
    this.newPanelTarget.hidden = !showNew
  }
}
