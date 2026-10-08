import { Controller } from '@hotwired/stimulus';

const STORAGE_KEY = 'transjrbi_sidebar_collapsed';

export default class extends Controller {
  static targets = ['desktop', 'toggleBtn'];

  connect() {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved === 'true') {
      this.applyCollapsed(true, false);
    }
  }

  toggle() {
    if (!this.hasDesktopTarget) return;

    const isCollapsed = this.desktopTarget.classList.contains('sidebar-collapsed');
    this.applyCollapsed(!isCollapsed, true);
  }

  applyCollapsed(collapsed, save) {
    if (!this.hasDesktopTarget) return;

    const desktop = this.desktopTarget;

    if (collapsed) {
      desktop.classList.add('sidebar-collapsed');
    } else {
      desktop.classList.remove('sidebar-collapsed');
    }

    if (this.hasToggleBtnTarget) {
      if (collapsed) {
        this.toggleBtnTarget.classList.add('is-active');
      } else {
        this.toggleBtnTarget.classList.remove('is-active');
      }
    }

    if (save) {
      localStorage.setItem(STORAGE_KEY, String(collapsed));
    }
  }
}
