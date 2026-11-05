import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['button', 'item'];
  static values = { key: String };
  static classes = ['active', 'inactive', 'hidden'];

  show({ params: { key } }) {
    this.keyValue = key;
  }

  keyValueChanged() {
    this.itemTargets.forEach(item => {
      this.toggle(item, this.hiddenClasses, item.dataset.revealKey !== this.keyValue);
    });

    this.buttonTargets.forEach(button => {
      const active = button.dataset.revealKeyParam === this.keyValue;

      this.toggle(button, this.activeClasses, active);
      this.toggle(button, this.inactiveClasses, !active);
      button.setAttribute('aria-pressed', String(active));
    });
  }

  toggle(element, classes, force) {
    classes.forEach(name => element.classList.toggle(name, force));
  }
}
