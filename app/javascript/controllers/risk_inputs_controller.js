import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["groupCheckbox", "lineItemCheckbox", "driverForm", "groupKeys", "lineItemIds", "applyButton", "groupLineRow", "distributionViz"]

  connect() {
    this.driverFormTargets.forEach((form) => {
      const distributionField = form.querySelector('[data-role="distribution"]')
      if (distributionField) this.updateDistribution({ target: distributionField })
    })
    this.selectionChanged()
  }

  submitFilters(event) {
    event.target.form.requestSubmit()
  }

  toggleGroupRows(event) {
    const button = event.currentTarget
    const groupKey = button.dataset.groupKey
    const expanded = button.getAttribute("aria-expanded") === "true"
    const nextExpanded = !expanded

    this.groupLineRowTargets
      .filter((row) => row.dataset.parentGroupKey === groupKey)
      .forEach((row) => row.classList.toggle("hidden", !nextExpanded))

    button.setAttribute("aria-expanded", String(nextExpanded))
    const icon = button.querySelector(".material-symbols-outlined")
    if (icon) icon.textContent = nextExpanded ? "expand_more" : "chevron_right"
  }

  selectionChanged() {
    const selectedGroupKeys = this.selectedGroupKeys()
    const selectedLineItemIds = this.selectedLineItemIds()
    const selectionCount = selectedGroupKeys.length + selectedLineItemIds.length

    this.driverFormTargets.forEach((form) => {
      const groupKeysContainer = form.querySelector('[data-risk-inputs-target="groupKeys"]')
      if (groupKeysContainer) {
        groupKeysContainer.innerHTML = selectedGroupKeys.map((key) => (
          `<input type="hidden" name="risk_input[driver_group_keys][]" value="${this.escapeHtml(key)}">`
        )).join("")
      }

      const lineItemIdsContainer = form.querySelector('[data-risk-inputs-target="lineItemIds"]')
      if (lineItemIdsContainer) {
        lineItemIdsContainer.innerHTML = selectedLineItemIds.map((id) => (
          `<input type="hidden" name="risk_input[line_item_ids][]" value="${id}">`
        )).join("")
      }
    })

    this.applyButtonTargets.forEach((button) => {
      button.disabled = selectionCount === 0
      button.textContent = `Apply to ${selectionCount} selected`
    })

    this.populateFromSingleSelection()
  }

  updateDistribution(event) {
    const form = event.target.closest("form")
    if (!form) return

    const distribution = form.querySelector('[data-role="distribution"]')?.value
    const minValue = form.querySelector('[data-role="min"]')?.value
    const maxValue = form.querySelector('[data-role="max"]')?.value
    const driverType = form.dataset.driverType
    const viz = this.distributionVizTargets.find((item) => item.dataset.driverType === driverType)
    if (!viz || !distribution) return

    viz.querySelectorAll("[data-distribution]").forEach((group) => {
      group.classList.toggle("hidden", group.dataset.distribution !== distribution)
    })

    const minLabel = viz.querySelector('[data-role="viz-min"]')
    const maxLabel = viz.querySelector('[data-role="viz-max"]')
    if (minLabel) minLabel.textContent = this.formatPercent(minValue)
    if (maxLabel) maxLabel.textContent = this.formatPercent(maxValue)
  }

  populateFromSingleSelection() {
    const selected = [
      ...this.groupCheckboxTargets.filter((checkbox) => checkbox.checked),
      ...this.lineItemCheckboxTargets.filter((checkbox) => checkbox.checked)
    ]
    if (selected.length !== 1) return

    const driverValues = JSON.parse(selected[0].dataset.driverValues || "{}")
    this.driverFormTargets.forEach((form) => {
      const driverType = form.dataset.driverType
      const values = driverValues[driverType]
      if (!values) return

      this.setFormValue(form, "source", values.source_accuracy_class)
      this.setFormValue(form, "distribution", values.distribution_type)
      this.setFormValue(form, "min", values.min_pct)
      this.setFormValue(form, "mode", values.mode_pct)
      this.setFormValue(form, "max", values.max_pct)
      this.updateDistribution({ target: form.querySelector('[data-role="distribution"]') })
    })
  }

  selectedGroupKeys() {
    return this.groupCheckboxTargets.filter((checkbox) => checkbox.checked).map((checkbox) => checkbox.value)
  }

  selectedLineItemIds() {
    return this.lineItemCheckboxTargets.filter((checkbox) => checkbox.checked).map((checkbox) => checkbox.value)
  }

  setFormValue(form, role, value) {
    const field = form.querySelector(`[data-role="${role}"]`)
    if (field && value != null) field.value = value
  }

  formatPercent(value) {
    if (value === null || value === undefined || value === "") return "0%"
    return `${value}%`
  }

  escapeHtml(value) {
    return value
      .replaceAll("&", "&amp;")
      .replaceAll('"', "&quot;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
  }
}
