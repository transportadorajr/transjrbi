import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import { Application } from '@hotwired/stimulus';
import AutoSubmitController from '../../../app/javascript/controllers/auto_submit_controller';

const tick = () => new Promise(resolve => setTimeout(resolve, 0));

const html = `
  <form data-controller="auto-submit" action="/history" method="get">
    <select name="start" data-action="change->auto-submit#submit">
      <option value="2026-11-01">Novembro</option>
      <option value="2026-10-01">Outubro</option>
    </select>
  </form>
`;

describe('AutoSubmitController', () => {
  let application;
  let submissions;

  beforeEach(async () => {
    submissions = [];
    document.body.innerHTML = html;
    document.querySelector('form').addEventListener('submit', event => {
      event.preventDefault();
      submissions.push(new FormData(event.target).get('start'));
    });
    application = Application.start();
    application.register('auto-submit', AutoSubmitController);
    await tick();
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  it('submits the form with the chosen option as soon as the select changes', () => {
    const select = document.querySelector('select');
    select.value = '2026-10-01';
    select.dispatchEvent(new Event('change'));

    expect(submissions).toEqual(['2026-10-01']);
  });
});
