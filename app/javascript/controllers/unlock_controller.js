import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['field', 'button'];

  enable() {
    this.fieldTargets.forEach(field => {
      field.disabled = false;
    });
    this.buttonTargets.forEach(button => button.classList.add('d-none'));
    this.fieldTargets[0]?.focus();
  }
}
