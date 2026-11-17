import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['partsTemplate', 'partsList', 'servicesTemplate', 'servicesList', 'row', 'total'];

  connect() {
    this.recalculate();
  }

  addParts() {
    this.add(this.partsTemplateTarget, this.partsListTarget);
  }

  addServices() {
    this.add(this.servicesTemplateTarget, this.servicesListTarget);
  }

  add(template, list) {
    const index = `${Date.now()}${list.children.length}`;
    list.insertAdjacentHTML('beforeend', template.innerHTML.replace(/NEW_RECORD/g, index));
    list.lastElementChild?.querySelector('input:not([type="hidden"]), select')?.focus();
    this.recalculate();
  }

  remove(event) {
    event.target.closest('[data-order-items-target="row"]')?.remove();
    this.recalculate();
  }

  recalculate() {
    if (!this.hasTotalTarget) return;

    const cents = this.rowTargets.reduce((sum, row) => sum + this.rowCents(row), 0);
    this.totalTarget.textContent = (cents / 100).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
  }

  rowCents(row) {
    const price = this.parseNumber(row.querySelector('[data-order-items-role="price"]')?.value);
    if (row.dataset.orderItemsKind === 'service') return Math.round(price * 100);

    const quantity = this.parseNumber(row.querySelector('[data-order-items-role="quantity"]')?.value);
    return Math.round(quantity * price * 100);
  }

  parseNumber(value) {
    return parseFloat((value || '').replace(/\./g, '').replace(',', '.')) || 0;
  }
}
