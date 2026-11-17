import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['source', 'field'];
  static values = { items: Object };

  fill(event) {
    if (!this.hasSourceTarget || !this.sourceTarget.contains(event.target)) return;

    const item = this.itemsValue[event.target.value];
    if (!item) return;

    this.fieldTargets.forEach(field => {
      const value = item[field.dataset.catalogFillKey];
      if (value === undefined || value === null || value === '') return;
      if (field.dataset.catalogFillOnlyBlank === 'true' && field.value.trim() !== '') return;

      field.value = value;
    });
  }
}
