import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['source', 'label'];
  static values = { copiedLabel: String, resetAfter: { type: Number, default: 2000 } };

  async copy() {
    await navigator.clipboard.writeText(this.sourceTarget.textContent);

    if (!this.hasLabelTarget) return;

    this.originalLabel ??= this.labelTarget.textContent;
    this.labelTarget.textContent = this.copiedLabelValue;
    clearTimeout(this.timeout);
    this.timeout = setTimeout(() => {
      this.labelTarget.textContent = this.originalLabel;
    }, this.resetAfterValue);
  }

  disconnect() {
    clearTimeout(this.timeout);
  }
}
