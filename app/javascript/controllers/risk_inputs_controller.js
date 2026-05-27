import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["packageCheckbox", "driverForm", "packageIds", "applyButton", "packageLineRow", "distributionViz"]

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

  togglePackageRows(event) {
    const button = event.currentTarget
    const packageId = button.dataset.packageId
    const expanded = button.getAttribute("aria-expanded") === "true"
    const nextExpanded = !expanded

    this.packageLineRowTargets
      .filter((row) => row.dataset.parentPackageId === packageId)
      .forEach((row) => row.classList.toggle("hidden", !nextExpanded))

    button.setAttribute("aria-expanded", String(nextExpanded))
    const icon = button.querySelector(".material-symbols-outlined")
    if (icon) icon.textContent = nextExpanded ? "expand_more" : "chevron_right"
  }

  selectionChanged() {
    const selectedIds = this.selectedPackageIds()

    this.driverFormTargets.forEach((form) => {
      const packageIdsContainer = form.querySelector('[data-risk-inputs-target="packageIds"]')
      if (!packageIdsContainer) return

      packageIdsContainer.innerHTML = selectedIds.map((id) => (
        `<input type="hidden" name="risk_input[package_value_ids][]" value="${id}">`
      )).join("")
    })

    this.applyButtonTargets.forEach((button) => {
      button.disabled = selectedIds.length === 0
      button.textContent = `Apply to ${selectedIds.length} selected package${selectedIds.length === 1 ? "" : "s"}`
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
    const selected = this.packageCheckboxTargets.filter((checkbox) => checkbox.checked)
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

  selectedPackageIds() {
    return this.packageCheckboxTargets.filter((checkbox) => checkbox.checked).map((checkbox) => checkbox.value)
  }

  setFormValue(form, role, value) {
    const field = form.querySelector(`[data-role="${role}"]`)
    if (field && value != null) field.value = value
  }

  formatPercent(value) {
    if (value === null || value === undefined || value === "") return "0%"
    return `${value}%`
  }
}
