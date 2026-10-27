import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import { Application } from '@hotwired/stimulus';
import MaskController from '../../../app/javascript/controllers/mask_controller';

const tick = (ms = 0) => new Promise(resolve => setTimeout(resolve, ms));

const html = `
  <input type="text" id="legal_id" data-controller="mask"
         data-mask-pattern-value='["000.000.000-00","00.000.000/0000-00"]'>
  <input type="text" id="digits" data-controller="mask" data-mask-regex-value="^\\d*$">
`;

describe('MaskController', () => {
  let application;

  const input = id => document.getElementById(id);

  const typeInto = (element, value) => {
    element.value = value;
    element.dispatchEvent(new Event('input', { bubbles: true }));
  };

  beforeEach(async () => {
    document.body.innerHTML = html;
    application = Application.start();
    application.register('mask', MaskController);
    await tick();
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  it('formats up to 11 digits as a CPF', () => {
    typeInto(input('legal_id'), '12345678901');

    expect(input('legal_id').value).toBe('123.456.789-01');
  });

  it('switches to the CNPJ pattern after 11 digits', () => {
    typeInto(input('legal_id'), '11222333000144');

    expect(input('legal_id').value).toBe('11.222.333/0001-44');
  });

  it('drops characters that are not digits', () => {
    typeInto(input('legal_id'), '123abc456');

    expect(input('legal_id').value).toBe('123.456');
  });

  it('accepts a regex mask', () => {
    typeInto(input('digits'), '12a3');

    expect(input('digits').value).toBe('123');
  });
});
