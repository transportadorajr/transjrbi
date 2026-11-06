import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import { Application } from '@hotwired/stimulus';
import DateRangeController from '../../../app/javascript/controllers/date_range_controller';

const tick = () => new Promise(resolve => setTimeout(resolve, 0));

const html = `
  <form data-controller="date-range">
    <input type="date" id="start_date" data-date-range-target="start" data-action="change->date-range#openEnd">
    <input type="date" id="end_date" data-date-range-target="end">
  </form>
`;

describe('DateRangeController', () => {
  let application;
  let pickers;

  const start = () => document.getElementById('start_date');
  const end = () => document.getElementById('end_date');

  const pick = value => {
    start().value = value;
    start().dispatchEvent(new Event('change', { bubbles: true }));
  };

  beforeEach(async () => {
    pickers = 0;
    document.body.innerHTML = html;
    end().showPicker = () => {
      pickers += 1;
    };

    application = Application.start();
    application.register('date-range', DateRangeController);
    await tick();
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  it('opens the end date picker as soon as the start date is filled in', () => {
    pick('2026-11-01');

    expect(pickers).toBe(1);
    expect(document.activeElement).toBe(end());
  });

  it('keeps the end date from going before the start date', () => {
    pick('2026-11-01');

    expect(end().min).toBe('2026-11-01');
  });

  it('waits for the whole year to be typed before opening the end date', () => {
    pick('0202-11-01');

    expect(pickers).toBe(0);
    expect(document.activeElement).not.toBe(end());
  });

  it('lifts the end date limit once the start date is cleared', () => {
    pick('2026-11-01');
    pick('');

    expect(end().hasAttribute('min')).toBe(false);
    expect(pickers).toBe(1);
  });

  it('still moves to the end date when the browser refuses to open the picker', () => {
    end().showPicker = () => {
      throw new Error('NotAllowedError');
    };

    pick('2026-11-01');

    expect(document.activeElement).toBe(end());
  });
});
