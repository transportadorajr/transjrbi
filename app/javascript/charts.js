import Chartkick from 'chartkick';
import { Chart } from 'chart.js';
import { toFont } from 'chart.js/helpers';
import ChartDataLabels from 'chartjs-plugin-datalabels';

const LABEL_PADDING = 8;
const INSIDE_LABEL_COLOR = '#ffffff';
const NEEDLE_LENGTH = 0.9;
const NEEDLE_WIDTH = 3;
const NEEDLE_HUB_RADIUS = 6;

const valueAxisOf = chart => (chart.options.indexAxis === 'y' ? 'x' : 'y');

export function formatBarLabel(value, { chart }) {
  if (!value) return null;

  const format = chart.options.plugins.tooltip?.callbacks?.label;

  return format ? format({ dataset: {}, parsed: { [valueAxisOf(chart)]: value } }) : String(value);
}

export function fitsInsideBar(context) {
  const { chart, dataset, datasetIndex, dataIndex } = context;
  const bar = chart.getDatasetMeta(datasetIndex).data[dataIndex];
  if (!bar) return true;

  const valueAxis = valueAxisOf(chart);
  const props = bar.getProps([valueAxis, 'base'], true);
  chart.ctx.font = toFont(chart.options.plugins.datalabels.font).string;
  const width = chart.ctx.measureText(formatBarLabel(dataset.data[dataIndex], context)).width;

  return width + LABEL_PADDING <= Math.abs(props[valueAxis] - props.base);
}

export function barLabelAlign(context) {
  return fitsInsideBar(context) ? 'start' : 'end';
}

export function barLabelColor(context) {
  return fitsInsideBar(context) ? INSIDE_LABEL_COLOR : context.dataset.backgroundColor;
}

export function gaugeNeedleAngle(value, max, startAngle) {
  const share = Math.min(Math.max(value / max, 0), 1);

  return startAngle + Math.PI * share;
}

export function drawGaugeNeedle(chart, _args, options) {
  if (options?.value == null) return;

  const arc = chart.getDatasetMeta(0).data[0];
  if (!arc) return;

  const { x, y, startAngle, outerRadius } = arc.getProps(['x', 'y', 'startAngle', 'outerRadius'], true);
  const angle = gaugeNeedleAngle(options.value, options.max, startAngle);
  const { ctx } = chart;

  ctx.save();
  ctx.strokeStyle = options.color;
  ctx.fillStyle = options.color;
  ctx.lineWidth = NEEDLE_WIDTH;
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.moveTo(x, y);
  ctx.lineTo(x + Math.cos(angle) * outerRadius * NEEDLE_LENGTH, y + Math.sin(angle) * outerRadius * NEEDLE_LENGTH);
  ctx.stroke();
  ctx.beginPath();
  ctx.arc(x, y, NEEDLE_HUB_RADIUS, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

export const goalGaugePlugin = { id: 'goalGauge', afterDatasetsDraw: drawGaugeNeedle };

export function destroyChartsOnRender(event) {
  const { render } = event.detail;
  if (!render) return;

  event.detail.render = (currentElement, newElement) => {
    Chartkick.destroyAll();
    return render(currentElement, newElement);
  };
}

Chartkick.config.autoDestroy = false;
document.addEventListener('turbo:before-render', destroyChartsOnRender);

Chart.register(ChartDataLabels, goalGaugePlugin);

Chart.defaults.plugins.datalabels.display = false;
Chart.defaults.plugins.datalabels.formatter = formatBarLabel;
Chart.defaults.plugins.datalabels.align = barLabelAlign;
Chart.defaults.plugins.datalabels.color = barLabelColor;
