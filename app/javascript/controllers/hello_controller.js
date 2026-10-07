import { Controller } from '@hotwired/stimulus';

// Controller de exemplo. Uso:
// <div data-controller="hello">...</div>
export default class extends Controller {
  static targets = ['name', 'output'];

  greet() {
    const name = this.nameTarget.value.trim() || 'mundo';
    this.outputTarget.textContent = `Olá, ${name}!`;
  }
}
