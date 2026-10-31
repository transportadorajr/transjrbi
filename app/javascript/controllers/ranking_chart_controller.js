import { Controller } from '@hotwired/stimulus';
import { Chart } from 'chart.js';

export default class extends Controller {
  static values = { urls: Array };

  open(event) {
    const url = this.urlAt(event);
    if (!url) return;

    const link = document.createElement('a');
    link.href = url;
    link.dataset.turboStream = 'true';
    link.hidden = true;
    document.body.append(link);
    link.click();
    link.remove();
  }

  hover(event) {
    this.element.classList.toggle('ranking-chart-link', Boolean(this.urlAt(event)));
  }

  urlAt(event) {
    const canvas = this.element.querySelector('canvas');
    const chart = canvas && Chart.getChart(canvas);
    if (!chart) return null;

    const { left, top } = canvas.getBoundingClientRect();
    const x = event.clientX - left;
    const y = event.clientY - top;
    const { y: categories } = chart.scales;
    if (x > chart.chartArea.right || y < categories.top || y > categories.bottom) return null;

    return this.urlsValue[categories.getValueForPixel(y)] || null;
  }
}
