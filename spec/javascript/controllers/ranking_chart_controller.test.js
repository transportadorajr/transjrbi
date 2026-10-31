import { afterEach, beforeEach, describe, expect, it, spyOn } from 'bun:test';
import { Application } from '@hotwired/stimulus';
import { Chart } from 'chart.js';
import RankingChartController from '../../../app/javascript/controllers/ranking_chart_controller';

const tick = () => new Promise(resolve => setTimeout(resolve, 0));

const ROW_HEIGHT = 50;
const fakeChart = {
  chartArea: { right: 400 },
  scales: { y: { top: 0, bottom: 100, getValueForPixel: y => Math.floor(y / ROW_HEIGHT) } },
};

describe('RankingChartController', () => {
  let application;
  let getChart;
  let followed;

  const wrapper = () => document.querySelector('#ranking');
  const fire = (type, clientX, clientY) =>
    wrapper()
      .querySelector('canvas')
      .dispatchEvent(new MouseEvent(type, { bubbles: true, clientX, clientY }));
  const remember = event => {
    if (event.target.tagName === 'A')
      followed.push([event.target.getAttribute('href'), event.target.dataset.turboStream]);
    event.preventDefault();
  };

  beforeEach(async () => {
    followed = [];
    document.addEventListener('click', remember);
    getChart = spyOn(Chart, 'getChart').mockReturnValue(fakeChart);
    document.body.innerHTML = `
      <div id="ranking" data-controller="ranking-chart"
           data-ranking-chart-urls-value='["/freights?key=A","/freights?key=B"]'
           data-action="click->ranking-chart#open mousemove->ranking-chart#hover">
        <canvas></canvas>
      </div>
    `;
    application = Application.start();
    application.register('ranking-chart', RankingChartController);
    await tick();
  });

  afterEach(() => {
    application.stop();
    getChart.mockRestore();
    document.removeEventListener('click', remember);
    document.body.innerHTML = '';
  });

  it('follows the url of the row under a click on the bar as a turbo stream', () => {
    fire('click', 200, 75);

    expect(followed).toEqual([['/freights?key=B', 'true']]);
  });

  it('follows the url of the row under a click on the name of the axis', () => {
    fire('click', 10, 25);

    expect(followed).toEqual([['/freights?key=A', 'true']]);
  });

  it('leaves no link behind', () => {
    fire('click', 200, 75);

    expect(document.querySelector('a')).toBeNull();
  });

  it('ignores a click out of the rows', () => {
    fire('click', 200, 150);
    fire('click', 500, 75);

    expect(followed).toEqual([]);
  });

  it('ignores a click while the chart is not drawn', () => {
    getChart.mockReturnValue(undefined);
    fire('click', 200, 75);

    expect(followed).toEqual([]);
  });

  it('marks the chart as clickable only over a row', () => {
    fire('mousemove', 200, 75);
    expect(wrapper().classList.contains('ranking-chart-link')).toBe(true);

    fire('mousemove', 200, 150);
    expect(wrapper().classList.contains('ranking-chart-link')).toBe(false);
  });
});
