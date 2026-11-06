import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import { Application } from '@hotwired/stimulus';
import AutoRefreshController from '../../../app/javascript/controllers/auto_refresh_controller';

const tick = (ms = 0) => new Promise(resolve => setTimeout(resolve, ms));

const html = `
  <div data-controller="auto-refresh" data-auto-refresh-interval-value="20">
    <div class="modal" id="filtersModal"></div>
  </div>
`;

describe('AutoRefreshController', () => {
  let application;
  let visits;

  const modal = () => document.getElementById('filtersModal');

  beforeEach(async () => {
    visits = [];
    window.Turbo = { visit: (url, options) => visits.push([url, options]) };

    document.body.innerHTML = html;
    application = Application.start();
    application.register('auto-refresh', AutoRefreshController);
    await tick();
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
    delete window.Turbo;
  });

  it('reloads the current page in place once the interval goes by', async () => {
    expect(visits).toEqual([]);

    await tick(40);

    expect(visits).toEqual([[window.location.href, { action: 'replace' }]]);
  });

  it('waits for an open modal to be closed before reloading the page', async () => {
    modal().classList.add('show');

    await tick(40);

    expect(visits).toEqual([]);

    modal().classList.remove('show');
    await tick(40);

    expect(visits).toHaveLength(1);
  });

  it('stops reloading once the page is left', async () => {
    document.body.innerHTML = '';

    await tick(40);

    expect(visits).toEqual([]);
  });

  it('reloads every five minutes by default', async () => {
    document.body.innerHTML = '<div data-controller="auto-refresh"></div>';
    await tick();

    const controller = application.getControllerForElementAndIdentifier(
      document.body.firstElementChild,
      'auto-refresh'
    );

    expect(controller.intervalValue).toBe(300000);
  });
});
