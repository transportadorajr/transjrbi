import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import Chartkick from 'chartkick';
import {
  barLabelAlign,
  barLabelColor,
  destroyChartsOnRender,
  drawGaugeNeedle,
  fitsInsideBar,
  formatBarLabel,
  gaugeNeedleAngle,
} from '../../app/javascript/charts';

const contextWith = (value, barLength, textWidth = 60) => ({
  chart: {
    options: {
      indexAxis: 'y',
      plugins: {
        tooltip: { callbacks: { label: ({ parsed }) => `R$ ${parsed.x.toFixed(2)}` } },
        datalabels: { font: { size: 11, weight: 600 } },
      },
    },
    ctx: { measureText: () => ({ width: textWidth }) },
    getDatasetMeta: () => ({ data: [{ getProps: () => ({ x: 20 + barLength, base: 20 }) }] }),
  },
  dataset: { data: [value], backgroundColor: '#2563eb' },
  datasetIndex: 0,
  dataIndex: 0,
});

describe('formatBarLabel', () => {
  it('formats the value like the tooltip', () => {
    expect(formatBarLabel(15000, contextWith(15000, 200))).toBe('R$ 15000.00');
  });

  it('leaves a bar without value unlabeled', () => {
    expect(formatBarLabel(0, contextWith(0, 0))).toBeNull();
  });
});

describe('fitsInsideBar', () => {
  it('fits a value in a bar long enough to hold it', () => {
    expect(fitsInsideBar(contextWith(15000, 200))).toBe(true);
  });

  it('does not fit a value in a bar too short to hold it', () => {
    expect(fitsInsideBar(contextWith(300, 40))).toBe(false);
  });

  it('measures a negative bar from its base', () => {
    expect(fitsInsideBar(contextWith(-1500, -200))).toBe(true);
  });
});

describe('barLabelAlign', () => {
  it('writes the value inside the end of a bar that holds it', () => {
    expect(barLabelAlign(contextWith(15000, 200))).toBe('start');
  });

  it('writes the value beside a short bar', () => {
    expect(barLabelAlign(contextWith(300, 40))).toBe('end');
  });
});

describe('barLabelColor', () => {
  it('writes the value in white inside the bar', () => {
    expect(barLabelColor(contextWith(15000, 200))).toBe('#ffffff');
  });

  it('writes the value beside a short bar in the color of the bar', () => {
    expect(barLabelColor(contextWith(300, 40))).toBe('#2563eb');
  });
});

describe('destroyChartsOnRender', () => {
  let destroyed;

  const beforeRender = () => {
    const rendered = [];
    const event = new CustomEvent('turbo:before-render', {
      detail: { render: (current, next) => rendered.push([current, next]) },
    });
    document.dispatchEvent(event);
    return { event, rendered };
  };

  beforeEach(() => {
    destroyed = [];
    Chartkick.charts = { 'chart-1': { destroy: () => destroyed.push('chart-1') } };
  });

  afterEach(() => {
    Chartkick.charts = {};
  });

  it('keeps the charts while turbo does not replace the page', () => {
    beforeRender();

    expect(destroyed).toEqual([]);
    expect(Object.keys(Chartkick.charts)).toEqual(['chart-1']);
  });

  it('destroys the charts right before turbo replaces the page', () => {
    const { event, rendered } = beforeRender();

    event.detail.render('current', 'next');

    expect(destroyed).toEqual(['chart-1']);
    expect(Chartkick.charts).toEqual({});
    expect(rendered).toEqual([['current', 'next']]);
  });

  it('ignores an event without a render function', () => {
    const event = { detail: {} };

    destroyChartsOnRender(event);

    expect(event.detail.render).toBeUndefined();
  });
});

describe('gaugeNeedleAngle', () => {
  it('turns the needle along the half circle in proportion to the value', () => {
    expect(gaugeNeedleAngle(0, 1.2, Math.PI)).toBe(Math.PI);
    expect(gaugeNeedleAngle(0.6, 1.2, Math.PI)).toBe(Math.PI * 1.5);
  });

  it('stops the needle at the ends of the scale', () => {
    expect(gaugeNeedleAngle(3, 1.2, Math.PI)).toBe(Math.PI * 2);
    expect(gaugeNeedleAngle(-1, 1.2, Math.PI)).toBe(Math.PI);
  });
});

describe('drawGaugeNeedle', () => {
  const gaugeChart = () => {
    const calls = [];
    const ctx = new Proxy(
      {},
      {
        get: (target, name) => (name in target ? target[name] : (...args) => calls.push([name, ...args])),
        set: (target, name, value) => {
          target[name] = value;
          return true;
        },
      }
    );
    const arc = { getProps: () => ({ x: 100, y: 100, startAngle: Math.PI, outerRadius: 50 }) };

    return { calls, chart: { ctx, getDatasetMeta: () => ({ data: [arc] }) } };
  };

  it('draws the needle from the center towards the value', () => {
    const { calls, chart } = gaugeChart();

    drawGaugeNeedle(chart, {}, { value: 0.6, max: 1.2, color: '#1a2a3a' });

    const [, x, y] = calls.find(([name]) => name === 'lineTo');
    expect(x).toBeCloseTo(100);
    expect(y).toBeCloseTo(55);
    expect(chart.ctx.strokeStyle).toBe('#1a2a3a');
  });

  it('draws nothing on a chart without a gauge value', () => {
    const { calls, chart } = gaugeChart();

    drawGaugeNeedle(chart, {}, {});

    expect(calls).toEqual([]);
  });
});
