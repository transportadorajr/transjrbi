import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import Chartkick from 'chartkick';
import {
  barLabelAlign,
  barLabelColor,
  destroyChartsOnRender,
  fitsInsideBar,
  formatBarLabel,
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
