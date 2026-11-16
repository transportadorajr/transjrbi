import { Controller } from '@hotwired/stimulus';

const normalize = text => (text || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim();

export default class extends Controller {
  static targets = ['company', 'amount', 'total', 'share', 'line'];
  static values = {
    unit: { type: String, default: 'R$' },
    separator: { type: String, default: ',' },
    delimiter: { type: String, default: '.' },
    share: { type: String, default: '{ratio}' },
  };

  connect() {
    this.refresh();
  }

  refresh() {
    const totals = this.amountTargets.reduce((sums, input) => {
      const section = input.dataset.section;
      sums[section] = (sums[section] || 0) + this.cents(input.value);
      return sums;
    }, {});
    const company = this.hasCompanyTarget ? this.cents(this.companyTarget.value) : 0;

    this.totalTargets.forEach(element => {
      element.textContent = this.money(totals[element.dataset.section] || 0);
    });
    this.shareTargets.forEach(element => {
      element.textContent = company > 0 ? this.shareText((totals[element.dataset.section] || 0) / company) : '';
    });
  }

  filter(event) {
    const query = normalize(event.target.value);
    const section = event.target.dataset.section;

    this.lineTargets
      .filter(line => line.dataset.section === section)
      .forEach(line => line.classList.toggle('d-none', !normalize(line.dataset.name).includes(query)));
  }

  cents(value) {
    const digits = (value || '').replace(/\D/g, '');
    return digits === '' ? 0 : parseInt(digits, 10);
  }

  money(cents) {
    return `${this.unitValue} ${this.number(cents / 100, 2)}`;
  }

  shareText(ratio) {
    return this.shareValue.replace('{ratio}', `${this.number(ratio * 100, 1)}%`);
  }

  number(value, precision) {
    const [units, decimals] = value.toFixed(precision).split('.');
    const grouped = units.replace(/\B(?=(\d{3})+(?!\d))/g, this.delimiterValue);
    return `${grouped}${this.separatorValue}${decimals}`;
  }
}
