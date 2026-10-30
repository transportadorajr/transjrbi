import Select2Controller from 'hotwire-select2';

const DOCUMENT_QUERY = /^[\d.\-/\s]+$/;

const normalize = text => text.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');

const digits = text => text.replace(/\D/g, '');

export default class extends Select2Controller {
  search() {
    const query = normalize(this.searchTarget.value);
    const documentQuery = DOCUMENT_QUERY.test(query) ? digits(query) : '';
    let hasVisible = false;

    this.optionTargets.forEach(option => {
      const label = option.dataset.label;
      const matches =
        normalize(label).includes(query) || (documentQuery !== '' && digits(label).includes(documentQuery));

      option.hidden = !matches;
      hasVisible ||= matches;
    });

    const noResults = this.dropdownTarget.querySelector('[data-select2-no-results]');
    if (noResults) noResults.hidden = hasVisible;
  }
}
