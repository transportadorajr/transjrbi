import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static values = { separator: { type: String, default: ',' }, delimiter: { type: String, default: '.' } };

  connect() {
    this.format = this.format.bind(this);
    this.element.addEventListener('input', this.format);
    this.format();
  }

  disconnect() {
    this.element.removeEventListener('input', this.format);
  }

  format() {
    const digits = this.element.value.replace(/\D/g, '').replace(/^0+/, '');

    if (digits === '') {
      this.element.value = '';
      return;
    }

    const padded = digits.padStart(3, '0');
    const units = padded.slice(0, -2).replace(/\B(?=(\d{3})+(?!\d))/g, this.delimiterValue);

    this.element.value = `${units}${this.separatorValue}${padded.slice(-2)}`;
    this.element.setSelectionRange?.(this.element.value.length, this.element.value.length);
  }
}
