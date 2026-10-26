import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "name", "key", "category", "icon", "sortOrder", "description", "defaultEnabled"]
  static values = { templates: Array }

  apply() {
    if (!this.selectTarget.value) {
      this.keyTarget.value = ""
      return
    }

    const template = this.templatesValue.find((item) => item.key === this.selectTarget.value)
    if (!template) return

    this.nameTarget.value = template.name
    this.keyTarget.value = template.key
    this.categoryTarget.value = template.category
    if (this.hasIconTarget) this.iconTarget.value = template.icon || ""
    if (this.hasSortOrderTarget) this.sortOrderTarget.value = template.sort_order || ""
    if (this.hasDescriptionTarget) this.descriptionTarget.value = template.description || ""
    if (this.hasDefaultEnabledTarget) this.defaultEnabledTarget.checked = Boolean(template.default_enabled)
  }
}
