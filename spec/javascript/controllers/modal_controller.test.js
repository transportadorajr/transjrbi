import { afterEach, describe, expect, it } from 'bun:test';
import { Application } from '@hotwired/stimulus';
import { Modal } from 'bootstrap';
import ModalController from '../../../app/javascript/controllers/modal_controller';

const tick = () => new Promise(resolve => setTimeout(resolve, 0));

const modalHtml = autoShow => `
  <div class="modal" id="my_modal" tabindex="-1" data-controller="modal" data-modal-auto-show-value="${autoShow}">
    <div class="modal-dialog">
      <div class="modal-content"></div>
    </div>
  </div>
`;

describe('ModalController', () => {
  let application;

  const modal = () => document.querySelector('#my_modal');

  const mount = async autoShow => {
    document.body.innerHTML = modalHtml(autoShow);
    application = Application.start();
    application.register('modal', ModalController);
    await tick();
  };

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
    document.body.className = '';
    document.body.removeAttribute('style');
  });

  it('opens the modal as soon as it is rendered when auto show is enabled', async () => {
    await mount(true);

    expect(modal().classList.contains('show')).toBe(true);
    expect(document.body.classList.contains('modal-open')).toBe(true);
  });

  it('keeps the modal closed when auto show is disabled', async () => {
    await mount(false);

    expect(modal().classList.contains('show')).toBe(false);
    expect(Modal.getInstance(modal())).toBeNull();
  });

  it('replaces the address of the page when a replace url is given', async () => {
    window.history.replaceState(null, '', '/freight_billing?start_date=2026-11-01&detail=total');
    document.body.innerHTML = `
      <div class="modal" id="my_modal" tabindex="-1" data-controller="modal" data-modal-auto-show-value="true"
           data-modal-replace-url-value="/freight_billing?start_date=2026-11-01">
        <div class="modal-dialog"><div class="modal-content"></div></div>
      </div>
    `;
    application = Application.start();
    application.register('modal', ModalController);
    await tick();

    expect(window.location.pathname + window.location.search).toBe('/freight_billing?start_date=2026-11-01');
    expect(modal().classList.contains('show')).toBe(true);
  });

  it('disposes the bootstrap instance when the modal leaves the page', async () => {
    await mount(true);
    const element = modal();

    element.remove();
    await tick();

    expect(Modal.getInstance(element)).toBeNull();
  });
});
