import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import { Application } from '@hotwired/stimulus';
import UnlockController from '../../../app/javascript/controllers/unlock_controller';

const tick = (ms = 0) => new Promise(resolve => setTimeout(resolve, ms));

const html = `
  <form data-controller="unlock">
    <select id="group" data-unlock-target="field" disabled><option value="1">USIMINAS</option></select>
    <input id="name" data-unlock-target="field" value="Brasiltec" disabled>
    <div id="unlock" data-unlock-target="button">
      <button type="button" id="unlock_button" data-action="unlock#enable">Alterar</button>
    </div>
  </form>
`;

describe('UnlockController', () => {
  let application;

  const element = id => document.getElementById(id);

  beforeEach(async () => {
    document.body.innerHTML = html;
    application = Application.start();
    application.register('unlock', UnlockController);
    await tick();
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  it('keeps the fields disabled until the button is clicked', () => {
    expect(element('group').disabled).toBe(true);
    expect(element('name').disabled).toBe(true);
  });

  it('enables the fields, hides the button and focuses the first field', async () => {
    element('unlock_button').click();
    await tick();

    expect(element('group').disabled).toBe(false);
    expect(element('name').disabled).toBe(false);
    expect(element('unlock').classList.contains('d-none')).toBe(true);
    expect(document.activeElement).toBe(element('group'));
  });
});
