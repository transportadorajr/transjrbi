import { Controller } from '@hotwired/stimulus';

const STORAGE_KEY = 'pagination:scroll';

export default class extends Controller {
  connect() {
    const pending = this.read();
    if (!pending || pending.url !== window.location.href || pending.index !== this.index()) return;

    this.clear();
    this.scroll = () => this.scrollToTable();
    document.addEventListener('turbo:load', this.scroll, { once: true });
  }

  disconnect() {
    if (this.scroll) document.removeEventListener('turbo:load', this.scroll);
  }

  remember(event) {
    const link = event.target.closest('a[href]');
    if (!link || new URL(link.href, window.location.href).hash) return;

    this.write({ url: new URL(link.href, window.location.href).href, index: this.index() });
  }

  scrollToTable() {
    const table = this.element.closest('.table-card, .card') || this.element;
    table.scrollIntoView({ block: 'start' });
  }

  index() {
    return [...document.querySelectorAll(`[data-controller~="${this.identifier}"]`)].indexOf(this.element);
  }

  read() {
    try {
      return JSON.parse(window.sessionStorage.getItem(STORAGE_KEY));
    } catch {
      return null;
    }
  }

  write(value) {
    try {
      window.sessionStorage.setItem(STORAGE_KEY, JSON.stringify(value));
    } catch {
      return;
    }
  }

  clear() {
    try {
      window.sessionStorage.removeItem(STORAGE_KEY);
    } catch {
      return;
    }
  }
}
