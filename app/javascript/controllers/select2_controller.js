import Select2Controller from 'hotwire-select2';

const DOCUMENT_QUERY = /^[\d.\-/\s]+$/;

const normalize = text => text.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');

const digits = text => text.replace(/\D/g, '');

export default class extends Select2Controller {
  static values = { ...Select2Controller.values, removeLabel: { type: String, default: 'Remover' } };

  _renderSelected() {
    if (!this.multipleValue || this._selectedValues.size === 0) {
      super._renderSelected();
      return;
    }

    const tags = document.createElement('div');
    tags.className = 'select2-tags';

    this._selectedValues.forEach((label, value) => {
      const tag = document.createElement('span');
      tag.className = 'select2-tag';

      const text = document.createElement('span');
      text.className = 'select2-tag__label';
      text.textContent = label;

      const remove = document.createElement('button');
      remove.type = 'button';
      remove.className = 'select2-tag__remove';
      remove.dataset.action = 'click->select2#removeTag';
      remove.dataset.value = value;
      remove.setAttribute('aria-label', `${this.removeLabelValue} ${label}`);
      remove.textContent = '×';

      tag.append(text, remove);
      tags.appendChild(tag);
    });

    this.selectedTarget.replaceChildren(tags);
  }

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
