import { Controller } from "@hotwired/stimulus"

const LEVELS = ["site", "building", "floor", "unit"]

const PARENT_LEVELS = {
  building: ["site"],
  floor: ["site", "building"],
  unit: ["site", "building", "floor"],
}

/**
 * Keeps site → building → floor → unit selects in sync.
 *
 * Each option carries data-site-id / data-building-id / data-floor-id, so the
 * controller can filter child options without a network request. Changing a
 * parent clears any child value that no longer belongs to it.
 */
export default class extends Controller {
  connect() {
    this.fields = {}
    this.snapshots = new Map()
    this.allowBlankParents =
      this.element.dataset.locationCascadeAllowBlankParents === "true"

    this.selects().forEach((select) => {
      const level = select.dataset.locationLevel
      if (!level) return

      this.fields[level] = select
      this.snapshots.set(
        select,
        Array.from(select.options).map((option) => ({
          value: option.value,
          label: option.textContent.trim(),
          disabled: option.disabled,
          dataset: { ...option.dataset },
        })),
      )
      select.addEventListener("change", this.handleChange)
    })

    this.inheritParentsFromSelection()
    this.refresh()
  }

  /**
   * Older records sometimes only stored a unit. Fill the parent selects from
   * the selected option so editing does not silently lose that location.
   */
  inheritParentsFromSelection() {
    ["unit", "floor", "building"].forEach((level) => {
      const select = this.fields[level]
      if (!select || !select.value) return

      const option = select.selectedOptions[0]
      if (!option) return

      const parents = PARENT_LEVELS[level] || []
      parents.forEach((parent) => {
        const parentSelect = this.fields[parent]
        const parentValue = option.dataset[`${parent}Id`]
        if (parentSelect && !parentSelect.value && parentValue) {
          parentSelect.value = String(parentValue)
        }
      })
    })
  }

  disconnect() {
    this.selects().forEach((select) => {
      select.removeEventListener("change", this.handleChange)
    })
  }

  selects() {
    return Array.from(
      this.element.querySelectorAll("select[data-location-level]"),
    )
  }

  handleChange = (event) => {
    const level = event.target.dataset.locationLevel
    const index = LEVELS.indexOf(level)

    if (index >= 0) {
      LEVELS.slice(index + 1).forEach((childLevel) => {
        const child = this.fields[childLevel]
        if (child && child.value !== "") {
          child.value = ""
          child.dispatchEvent(new Event("change", { bubbles: true }))
        }
      })
    }

    this.refresh()
  }

  refresh() {
    const selected = {}
    LEVELS.forEach((level) => {
      selected[level] = this.fields[level]?.value ?? ""
    })

    LEVELS.forEach((level) => {
      const select = this.fields[level]
      if (!select) return

      const parents = (PARENT_LEVELS[level] || []).filter(
        (parent) => this.fields[parent],
      )
      const snapshot = this.snapshots.get(select) || []
      const hasUnselectedParent = parents.some(
        (parent) => !selected[parent],
      )

      const allowed = snapshot.filter((option) => {
        if (option.value === "") return true

        return parents.every((parent) => {
          const parentValue = selected[parent]
          if (!parentValue) return this.allowBlankParents
          return String(option.dataset[`${parent}Id`] ?? "") === String(parentValue)
        })
      })

      const currentValue = select.value
      select.innerHTML = ""

      allowed.forEach((option) => {
        const element = document.createElement("option")
        element.value = option.value
        element.textContent = option.label
        element.disabled = option.disabled
        Object.entries(option.dataset).forEach(([key, value]) => {
          element.dataset[key] = value
        })
        select.appendChild(element)
      })

      if (parents.length > 0) {
        select.disabled =
          (!this.allowBlankParents && hasUnselectedParent) ||
          !allowed.some((option) => option.value !== "")
      }

      if (
        currentValue &&
        allowed.some(
          (option) => option.value === currentValue && !option.disabled,
        )
      ) {
        select.value = currentValue
      } else if (currentValue) {
        select.value = ""
      }
    })
  }
}
