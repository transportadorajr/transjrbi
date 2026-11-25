import { Controller } from '@hotwired/stimulus';

const COMPLETE_DATE = /^[1-9]\d{3}-\d{2}-\d{2}$/;

export default class extends Controller {
  static targets = ['start', 'end'];

  connect() {
    this.limitEnd();
  }

  openEnd() {
    this.limitEnd();

    if (!COMPLETE_DATE.test(this.startTarget.value)) return;

    this.endTarget.focus();

    try {
      this.endTarget.showPicker();
    } catch {
      this.endTarget.click();
    }
  }

  followStart() {
    this.limitEnd();

    if (!COMPLETE_DATE.test(this.startTarget.value)) return;
    if (this.endTarget.value && this.endTarget.value >= this.startTarget.value) return;

    this.endTarget.value = this.startTarget.value;
    this.endTarget.dispatchEvent(new Event('change', { bubbles: true }));
  }

  limitEnd() {
    if (!this.hasStartTarget || !this.hasEndTarget) return;

    if (COMPLETE_DATE.test(this.startTarget.value)) {
      this.endTarget.min = this.startTarget.value;
    } else {
      this.endTarget.removeAttribute('min');
    }
  }
}
