import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['frame'];
  static values = { url: String, param: String, selectedParam: String };

  reload({ target }) {
    if (target.type !== 'hidden') return;

    const url = new URL(this.urlValue, window.location.origin);
    url.searchParams.set(this.paramValue, target.value);

    const selected = this.frameTarget.querySelector(`input[name="${this.selectedParamValue}"]`);
    if (selected) url.searchParams.set(this.selectedParamValue, selected.value);

    this.frameTarget.src = url.pathname + url.search;
  }
}
