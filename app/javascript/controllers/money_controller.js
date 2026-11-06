import { Controller } from '@hotwired/stimulus';
import IMask from 'imask';

export default class extends Controller {
  static values = { separator: { type: String, default: ',' }, delimiter: { type: String, default: '.' } };

  connect() {
    this.imask = IMask(this.element, {
      mask: Number,
      scale: 2,
      min: 0,
      radix: this.separatorValue,
      mapToRadix: ['.', ','].filter(character => character !== this.delimiterValue),
      thousandsSeparator: this.delimiterValue,
      padFractionalZeros: true,
      normalizeZeros: true,
    });
  }

  disconnect() {
    this.imask?.destroy();
  }
}
