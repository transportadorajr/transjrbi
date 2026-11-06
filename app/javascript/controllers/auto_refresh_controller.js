import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static values = { interval: { type: Number, default: 300000 } };

  intervalValueChanged() {
    this.schedule();
  }

  disconnect() {
    clearTimeout(this.timeout);
  }

  schedule() {
    clearTimeout(this.timeout);
    this.timeout = setTimeout(() => this.refresh(), this.intervalValue);
  }

  refresh() {
    if (document.querySelector('.modal.show')) {
      this.schedule();
      return;
    }

    window.Turbo.visit(window.location.href, { action: 'replace' });
  }
}
