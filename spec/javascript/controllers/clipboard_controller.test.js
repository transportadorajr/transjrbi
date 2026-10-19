import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import { Application } from '@hotwired/stimulus';
import ClipboardController from '../../../app/javascript/controllers/clipboard_controller';

const tick = (ms = 0) => new Promise(resolve => setTimeout(resolve, ms));

const html = `
  <div data-controller="clipboard" data-clipboard-copied-label-value="Copiado!" data-clipboard-reset-after-value="20">
    <button type="button" data-action="clipboard#copy"><span data-clipboard-target="label">Copiar</span></button>
    <pre data-clipboard-target="source">{"status": 200}</pre>
  </div>
`;

describe('ClipboardController', () => {
  let application;
  let copied;

  const button = () => document.querySelector('button');
  const label = () => document.querySelector('[data-clipboard-target="label"]');

  beforeEach(async () => {
    copied = null;
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: { writeText: async text => (copied = text) },
    });

    document.body.innerHTML = html;
    application = Application.start();
    application.register('clipboard', ClipboardController);
    await tick();
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  it('copies the source content to the clipboard', async () => {
    button().click();
    await tick();

    expect(copied).toBe('{"status": 200}');
  });

  it('shows the copied label and restores the original one afterwards', async () => {
    button().click();
    await tick();

    expect(label().textContent).toBe('Copiado!');

    await tick(40);

    expect(label().textContent).toBe('Copiar');
  });
});
