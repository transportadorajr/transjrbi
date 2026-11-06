import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import { Application } from '@hotwired/stimulus';
import MoneyController from '../../../app/javascript/controllers/money_controller';

const tick = (ms = 0) => new Promise(resolve => setTimeout(resolve, ms));

const html = `
  <input type="text" id="rate" value="12,57" data-controller="money"
         data-money-separator-value="," data-money-delimiter-value=".">
`;

describe('MoneyController', () => {
  let application;

  const input = () => document.getElementById('rate');

  const typeInto = value => {
    input().value = value;
    input().dispatchEvent(new Event('input', { bubbles: true }));
  };

  beforeEach(async () => {
    document.body.innerHTML = html;
    application = Application.start();
    application.register('money', MoneyController);
    await tick();
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  it('keeps the value already loaded in the field', () => {
    expect(input().value).toBe('12,57');
  });

  it('groups the thousands and keeps two decimals', () => {
    typeInto('1234,567');

    expect(input().value).toBe('1.234,56');
  });

  it('accepts a value pasted with the thousands separator', () => {
    typeInto('1.012,5');

    expect(input().value).toBe('1.012,5');
  });

  it('drops letters and negative signs', () => {
    typeInto('-12a,3');

    expect(input().value).toBe('12,3');
  });
});
