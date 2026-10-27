import { Controller } from '@hotwired/stimulus';
import IMask from 'imask';

export default class extends Controller {
  static values = { pattern: Array, regex: String };

  connect() {
    const maskOptions = { mask: this.mask };

    if (Array.isArray(this.mask) && this.mask.length > 1) {
      maskOptions.dispatch = (appended, dynamicMasked) => {
        const number = (dynamicMasked.value + appended).replace(/\D/g, '');

        if (number.length <= 11) {
          return dynamicMasked.compiledMasks[0];
        }
        return dynamicMasked.compiledMasks[1];
      };
    }

    this.imask = IMask(this.element, maskOptions);
  }

  get mask() {
    if (this.hasRegexValue) {
      return new RegExp(this.regexValue);
    }

    return this.patternValue.map(pattern => ({
      mask: pattern,
    }));
  }

  disconnect() {
    this.imask?.destroy();
  }
}
