import { Controller } from '@hotwired/stimulus';
import { Modal } from 'bootstrap';

export default class extends Controller {
  static values = { autoShow: Boolean, replaceUrl: String };

  connect() {
    if (this.replaceUrlValue) {
      window.history.replaceState(window.history.state, '', this.replaceUrlValue);
    }

    if (this.autoShowValue) {
      Modal.getOrCreateInstance(this.element).show();
    }
  }

  disconnect() {
    Modal.getInstance(this.element)?.dispose();
  }
}
