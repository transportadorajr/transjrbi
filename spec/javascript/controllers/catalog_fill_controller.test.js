import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import { Application } from '@hotwired/stimulus';
import CatalogFillController from '../../../app/javascript/controllers/catalog_fill_controller';

const tick = () => new Promise(resolve => setTimeout(resolve, 0));

const items = {
  1: { code: 'LF-123', description: 'LONA DE FREIO', unit: null, unit_price: '85,00' },
};

const html = `
  <div data-controller="catalog-fill" data-action="change->catalog-fill#fill"
       data-catalog-fill-items-value='${JSON.stringify(items)}'>
    <div data-catalog-fill-target="source">
      <input type="hidden" id="source" name="part[maintenance_part_id]">
    </div>
    <input id="code" data-catalog-fill-target="field" data-catalog-fill-key="code">
    <input id="unit" value="KG" data-catalog-fill-target="field" data-catalog-fill-key="unit">
    <input id="price" value="90,00" data-catalog-fill-target="field" data-catalog-fill-key="unit_price"
           data-catalog-fill-only-blank="true">
    <input id="other" data-catalog-fill-target="field" data-catalog-fill-key="description">
  </div>
`;

describe('CatalogFillController', () => {
  let application;

  const choose = (id, value) => {
    const input = document.getElementById(id);
    input.value = value;
    input.dispatchEvent(new Event('change', { bubbles: true }));
  };
  const value = id => document.getElementById(id).value;

  beforeEach(async () => {
    document.body.innerHTML = html;
    application = Application.start();
    application.register('catalog-fill', CatalogFillController);
    await tick();
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  it('fills the fields with the chosen item', () => {
    choose('source', '1');

    expect(value('code')).toBe('LF-123');
    expect(value('other')).toBe('LONA DE FREIO');
  });

  it('keeps a field when the item has no value for it', () => {
    choose('source', '1');

    expect(value('unit')).toBe('KG');
  });

  it('keeps a filled field marked to be filled only when blank', () => {
    choose('source', '1');

    expect(value('price')).toBe('90,00');
  });

  it('ignores the changes of the other fields and an unknown item', () => {
    choose('other', 'TEXTO');
    expect(value('code')).toBe('');

    choose('source', '99');
    expect(value('code')).toBe('');
  });
});
