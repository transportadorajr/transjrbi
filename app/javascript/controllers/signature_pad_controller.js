import { Controller } from '@hotwired/stimulus';

const PRECISION = 1000;
const LINE_WIDTH = 2;
const INK_COLOR = '#111111';

const clamp = value => Math.min(1, Math.max(0, value));
const round = value => Math.round(clamp(value) * PRECISION) / PRECISION;

export default class extends Controller {
  static targets = ['canvas', 'input'];

  connect() {
    this.ink = this.canvasTarget.getContext ? this.canvasTarget.getContext('2d') : null;
    this.strokes = this.parse(this.inputTarget.value);
    this.current = null;
    this.mark();
    this.resize();

    if (typeof ResizeObserver !== 'undefined') {
      this.observer = new ResizeObserver(() => this.resize());
      this.observer.observe(this.canvasTarget);
    }
  }

  disconnect() {
    this.observer?.disconnect();
  }

  start(event) {
    if (event.button !== undefined && event.button > 0) return;

    event.preventDefault();
    this.canvasTarget.setPointerCapture?.(event.pointerId);
    this.current = [this.point(event)];
    this.strokes.push(this.current);
    this.draw();
  }

  move(event) {
    if (!this.current) return;

    event.preventDefault();
    const events = event.getCoalescedEvents?.() || [];
    (events.length > 0 ? events : [event]).forEach(item => this.current.push(this.point(item)));
    this.draw();
  }

  end() {
    if (!this.current) return;

    this.current = null;
    this.store();
  }

  clear() {
    this.strokes = [];
    this.current = null;
    this.store();
    this.draw();
  }

  undo() {
    this.strokes.pop();
    this.current = null;
    this.store();
    this.draw();
  }

  point(event) {
    const rect = this.canvasTarget.getBoundingClientRect();
    const width = rect.width || 1;
    const height = rect.height || 1;

    return [round((event.clientX - rect.left) / width), round((event.clientY - rect.top) / height)];
  }

  store() {
    this.inputTarget.value = this.strokes.length > 0 ? JSON.stringify(this.strokes) : '';
    this.mark();
  }

  mark() {
    this.element.classList.toggle('signature-pad-signed', this.strokes.length > 0);
  }

  parse(value) {
    try {
      const strokes = JSON.parse(value || '[]');
      return Array.isArray(strokes) ? strokes.filter(Array.isArray) : [];
    } catch {
      return [];
    }
  }

  resize() {
    const rect = this.canvasTarget.getBoundingClientRect();
    if (!this.ink || rect.width === 0) return;

    const ratio = window.devicePixelRatio || 1;
    this.canvasTarget.width = Math.round(rect.width * ratio);
    this.canvasTarget.height = Math.round(rect.height * ratio);
    this.ink.setTransform(ratio, 0, 0, ratio, 0, 0);
    this.draw();
  }

  draw() {
    if (!this.ink) return;

    const rect = this.canvasTarget.getBoundingClientRect();
    this.ink.clearRect(0, 0, rect.width, rect.height);
    this.ink.lineWidth = LINE_WIDTH;
    this.ink.lineCap = 'round';
    this.ink.lineJoin = 'round';
    this.ink.strokeStyle = INK_COLOR;

    this.strokes.forEach(stroke => {
      this.ink.beginPath();
      stroke.forEach(([x, y], index) => {
        const method = index === 0 ? 'moveTo' : 'lineTo';
        this.ink[method](x * rect.width, y * rect.height);
      });
      if (stroke.length === 1) this.ink.lineTo(stroke[0][0] * rect.width + 0.1, stroke[0][1] * rect.height);
      this.ink.stroke();
    });
  }
}
