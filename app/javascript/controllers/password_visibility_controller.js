import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button", "icon"]

  toggle() {
    const visible = this.inputTarget.type === "password"

    this.inputTarget.type = visible ? "text" : "password"
    this.buttonTarget.setAttribute("aria-pressed", visible)
    this.iconTarget.classList.toggle("bi-eye", !visible)
    this.iconTarget.classList.toggle("bi-eye-slash", visible)
    this.inputTarget.focus()
  }
}
