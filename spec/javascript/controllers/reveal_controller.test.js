import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import { Application } from '@hotwired/stimulus';
import RevealController from '../../../app/javascript/controllers/reveal_controller';

const tick = (ms = 0) => new Promise(resolve => setTimeout(resolve, ms));

const html = `
  <div data-controller="reveal" data-reveal-key-value="monthly" data-reveal-active-class="btn-primary"
       data-reveal-inactive-class="btn-outline-secondary" data-reveal-hidden-class="d-none">
    <button type="button" id="monthly_button" data-reveal-target="button" data-reveal-key-param="monthly" data-action="reveal#show">Mensal</button>
    <button type="button" id="weekly_button" data-reveal-target="button" data-reveal-key-param="weekly" data-action="reveal#show">Semanal</button>
    <div id="monthly_revenue" data-reveal-target="item" data-reveal-key="monthly"></div>
    <div id="weekly_revenue" data-reveal-target="item" data-reveal-key="weekly"></div>
    <div id="weekly_per_km" data-reveal-target="item" data-reveal-key="weekly"></div>
  </div>
`;

describe('RevealController', () => {
  let application;

  const element = id => document.getElementById(id);
  const hidden = () =>
    [...document.querySelectorAll('[data-reveal-target="item"]')]
      .filter(item => item.classList.contains('d-none'))
      .map(item => item.id);

  beforeEach(async () => {
    document.body.innerHTML = html;
    application = Application.start();
    application.register('reveal', RevealController);
    await tick();
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  it('shows only the items of the initial key', () => {
    expect(hidden()).toEqual(['weekly_revenue', 'weekly_per_km']);
    expect(element('monthly_button').className).toBe('btn-primary');
    expect(element('weekly_button').className).toBe('btn-outline-secondary');
    expect(element('monthly_button').getAttribute('aria-pressed')).toBe('true');
  });

  it('reveals every item of the clicked key and hides the others', async () => {
    element('weekly_button').click();
    await tick();

    expect(hidden()).toEqual(['monthly_revenue']);
    expect(element('weekly_button').className).toBe('btn-primary');
    expect(element('monthly_button').className).toBe('btn-outline-secondary');
    expect(element('weekly_button').getAttribute('aria-pressed')).toBe('true');
    expect(element('monthly_button').getAttribute('aria-pressed')).toBe('false');
  });
});
