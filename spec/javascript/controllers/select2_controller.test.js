import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import { Application } from '@hotwired/stimulus';
import Select2Controller from '../../../app/javascript/controllers/select2_controller';

const tick = (ms = 0) => new Promise(resolve => setTimeout(resolve, ms));

const html = `
  <div data-controller="select2" data-select2-name="customer_code">
    <input type="hidden" name="customer_code" data-select2-target="hiddenInput">
    <div data-select2-target="selected"></div>
    <div data-select2-target="dropdown">
      <input type="search" data-select2-target="search">
      <ul>
        <li data-select2-target="option" data-value="1" data-label="USIMINAS - 12.345.678/0001-90">a</li>
        <li data-select2-target="option" data-value="2" data-label="JOÃO 100 - 98.765.432/0001-10">b</li>
        <li data-select2-no-results hidden>none</li>
      </ul>
    </div>
  </div>
`;

describe('Select2Controller', () => {
  let application;

  const search = query => {
    document.querySelector('input[type="search"]').value = query;
    application.getControllerForElementAndIdentifier(document.querySelector('[data-controller]'), 'select2').search();
  };
  const visible = () =>
    [...document.querySelectorAll('[data-select2-target="option"]')]
      .filter(option => !option.hidden)
      .map(option => option.dataset.value);
  const noResults = () => document.querySelector('[data-select2-no-results]');

  beforeEach(async () => {
    document.body.innerHTML = html;
    application = Application.start();
    application.register('select2', Select2Controller);
    await tick();
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  it('matches the name ignoring case and accents', () => {
    search('joao');

    expect(visible()).toEqual(['2']);
  });

  it('matches the document typed with only digits', () => {
    search('12345678');

    expect(visible()).toEqual(['1']);
  });

  it('matches the document typed with its punctuation', () => {
    search('98.765');

    expect(visible()).toEqual(['2']);
  });

  it('does not compare the digits of a query that has letters', () => {
    search('usiminas 12');

    expect(visible()).toEqual([]);
  });

  it('shows the no results message when nothing matches', () => {
    search('xyz');

    expect(noResults().hidden).toBe(false);
  });
});
