import { Controller } from '@hotwired/stimulus';
import { Modal } from 'bootstrap';

export default class extends Controller {
  static values = { autoShow: Boolean };

  connect() {
    if (this.autoShowValue) {
      Modal.getOrCreateInstance(this.element).show();
    }
  }

  disconnect() {
    Modal.getInstance(this.element)?.dispose();
  }
}
