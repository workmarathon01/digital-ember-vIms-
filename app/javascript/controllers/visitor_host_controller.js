import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "unit", "host" ]
  static values = { url: String, selected: String }

  connect() {
    if (this.unitTarget.value) {
      this.fetchHosts(this.selectedValue)
    } else {
      this.hostTarget.innerHTML = '<option value="">Select host</option>'
    }
  }

  refresh() {
    this.fetchHosts("")
  }

  async fetchHosts(selectedId) {
    const unitId = this.unitTarget.value
    this.hostTarget.innerHTML = '<option value="">Select host</option>'

    if (!unitId) return

    try {
      const response = await fetch(`${this.urlValue}?unit_id=${encodeURIComponent(unitId)}`, {
        headers: { Accept: "application/json" }
      })
      if (!response.ok) return

      const payload = await response.json()
      for (const host of payload.hosts || []) {
        const label = host.role_label ? `${host.full_name} (${host.role_label})` : host.full_name
        const option = new Option(label, host.id, false, String(host.id) === String(selectedId))
        this.hostTarget.add(option)
      }
    } catch {
      // The selector remains empty; the visitor can still be saved without a host.
    }
  }
}
