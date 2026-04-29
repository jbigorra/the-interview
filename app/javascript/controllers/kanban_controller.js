import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["column"]

  connect() {
    this.columnTargets.forEach((column) => {
      const container = column.querySelector("[data-stage-value]")
      if (!container) return

      new Sortable(container, {
        group: "kanban",
        animation: 150,
        ghostClass: "opacity-50",
        onEnd: (evt) => this.moveLead(evt),
      })
    })
  }

  moveLead(evt) {
    const leadId = evt.item.dataset.leadId
    if (!leadId) return

    const newStage = evt.to.dataset.stageValue
    const newPosition = evt.newIndex

    const csrfToken = document.querySelector("[name='csrf-token']")
    if (!csrfToken) return

    fetch(`/leads/${leadId}/move`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken.content,
        Accept: "text/vnd.turbo-stream.html",
      },
      body: JSON.stringify({ stage: newStage, position: newPosition }),
    })
      .then((response) => {
        if (response.ok) {
          return response.text().then((html) => {
            Turbo.renderStreamMessage(html)
          })
        } else {
          this.revertCard(evt)
          this.showError("Failed to move lead. Please try again.")
        }
      })
      .catch(() => {
        this.revertCard(evt)
        this.showError("Network error. Please check your connection.")
      })
  }

  revertCard(evt) {
    evt.item.remove()
    const referenceNode = evt.from.children[evt.oldIndex] || null
    evt.from.insertBefore(evt.item, referenceNode)
  }

  showError(message) {
    const flash = document.getElementById("flash")
    if (!flash) return

    const div = document.createElement("div")
    div.innerHTML = `<div class="fixed top-4 right-4 bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded z-50">${message}</div>`
    flash.appendChild(div.firstElementChild)
  }
}
