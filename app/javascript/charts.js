import { Chart } from 'chart.js';
import { toFont } from 'chart.js/helpers';
import ChartDataLabels from 'chartjs-plugin-datalabels';

const LABEL_PADDING = 8;
const INSIDE_LABEL_COLOR = '#ffffff';

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

Chart.register(ChartDataLabels);

Chart.defaults.plugins.datalabels.display = false;
Chart.defaults.plugins.datalabels.formatter = formatBarLabel;
Chart.defaults.plugins.datalabels.align = barLabelAlign;
Chart.defaults.plugins.datalabels.color = barLabelColor;
