import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import { Application } from '@hotwired/stimulus';
import MoneyController from '../../../app/javascript/controllers/money_controller';

const tick = (ms = 0) => new Promise(resolve => setTimeout(resolve, ms));

const html = `
  <input type="text" id="rate" value="1012,5" data-controller="money"
         data-money-separator-value="," data-money-delimiter-value=".">
`;

describe('MoneyController', () => {
  let application;

  const input = () => document.getElementById('rate');

  const typeInto = value => {
    input().value = value;
    input().dispatchEvent(new Event('input', { bubbles: true }));
  };

  const typeKeys = keys => {
    typeInto('');
    [...keys].forEach(key => typeInto(input().value + key));
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

  it('formats the value already loaded in the field', () => {
    expect(input().value).toBe('101,25');
  });

  it('keeps the last two digits typed as the cents', () => {
    typeKeys('1');
    expect(input().value).toBe('0,01');

    typeKeys('12');
    expect(input().value).toBe('0,12');

    typeKeys('1257');
    expect(input().value).toBe('12,57');

    typeKeys('123456789');
    expect(input().value).toBe('1.234.567,89');
  });

  it('moves the digits back to the cents when one is erased', () => {
    typeKeys('1257');
    typeInto('12,5');

    expect(input().value).toBe('1,25');
  });

  it('ignores letters, signs and separators typed by the user', () => {
    typeInto('-9a.5,0');

    expect(input().value).toBe('9,50');
  });

  it('clears the field when every digit is erased', () => {
    typeInto('0,0');

    expect(input().value).toBe('');
  });
});
