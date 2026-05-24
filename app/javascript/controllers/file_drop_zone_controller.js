import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["zone", "input", "status"]
  static classes = ["dragover"]

  dragover(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "copy"
    this.zoneTarget.classList.add(...this.dragoverClasses)
  }

  dragleave(event) {
    event.preventDefault()
    if (!this.zoneTarget.contains(event.relatedTarget)) {
      this.clearDragover()
    }
  }

  drop(event) {
    event.preventDefault()
    this.clearDragover()

    const file = event.dataTransfer.files[0]
    if (file) this.applyFile(file)
  }

  fileSelected() {
    const file = this.inputTarget.files[0]
    if (file) this.applyFile(file)
  }

  applyFile(file) {
    if (!this.isAllowed(file)) {
      this.setStatus(`"${file.name}" is not supported. Use .xlsx or .csv.`, true)
      return
    }

    const transfer = new DataTransfer()
    transfer.items.add(file)
    this.inputTarget.files = transfer.files

    this.setStatus(`Uploading ${file.name}…`, false)
    this.element.requestSubmit()
  }

  isAllowed(file) {
    const name = file.name.toLowerCase()
    return name.endsWith(".xlsx") || name.endsWith(".csv")
  }

  setStatus(message, isError) {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = message
    this.statusTarget.classList.toggle("text-error", isError)
    this.statusTarget.classList.toggle("text-on-surface-variant", !isError)
    this.statusTarget.classList.remove("hidden")
  }

  clearDragover() {
    this.zoneTarget.classList.remove(...this.dragoverClasses)
  }
}
