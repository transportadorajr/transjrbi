import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import { Application } from '@hotwired/stimulus';
import OrderItemsController from '../../../app/javascript/controllers/order_items_controller';

const tick = () => new Promise(resolve => setTimeout(resolve, 0));

const partRow = `
  <div data-order-items-target="row" data-order-items-kind="part">
    <input name="order[parts_attributes][NEW_RECORD][quantity]" data-order-items-role="quantity">
    <input name="order[parts_attributes][NEW_RECORD][unit_price]" data-order-items-role="price">
    <button type="button" data-action="order-items#remove">x</button>
  </div>
`;

const serviceRow = `
  <div data-order-items-target="row" data-order-items-kind="service">
    <input name="order[services_attributes][NEW_RECORD][quoted]" data-order-items-role="price">
  </div>
`;

const html = `
  <div data-controller="order-items" data-action="input->order-items#recalculate">
    <template data-order-items-target="partsTemplate">${partRow}</template>
    <div data-order-items-target="partsList"></div>
    <template data-order-items-target="servicesTemplate">${serviceRow}</template>
    <div data-order-items-target="servicesList"></div>
    <button id="add-part" type="button" data-action="order-items#addParts">part</button>
    <button id="add-service" type="button" data-action="order-items#addServices">service</button>
    <p data-order-items-target="total"></p>
  </div>
`;

describe('OrderItemsController', () => {
  let application;

  const click = id => document.getElementById(id).click();
  const added = selector => document.querySelector(`[data-order-items-target$="List"] ${selector}`);
  const total = () => document.querySelector('[data-order-items-target="total"]').textContent.replace(/\s/g, ' ');
  const type = (input, value) => {
    input.value = value;
    input.dispatchEvent(new Event('input', { bubbles: true }));
  };

  beforeEach(async () => {
    document.body.innerHTML = html;
    application = Application.start();
    application.register('order-items', OrderItemsController);
    await tick();
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  it('adds rows with a unique index', () => {
    click('add-part');
    click('add-part');

    const names = [...document.querySelectorAll('[data-order-items-target="partsList"] [name$="[quantity]"]')].map(
      input => input.name
    );
    expect(names).toHaveLength(2);
    expect(names.some(name => name.includes('NEW_RECORD'))).toBe(false);
    expect(new Set(names).size).toBe(2);
  });

  it('sums the parts and the services', () => {
    click('add-part');
    click('add-service');

    type(added('[data-order-items-role="quantity"]'), '2,5');
    type(added('[name*="unit_price"]'), '10,00');
    type(added('[name*="quoted"]'), '1.000,50');

    expect(total()).toBe('R$ 1.025,50');
  });

  it('removes a row and its value from the total', async () => {
    click('add-part');
    await tick();
    type(added('[data-order-items-role="quantity"]'), '1');
    type(added('[name*="unit_price"]'), '5,00');

    added('[data-action="order-items#remove"]').click();

    expect(
      document.querySelectorAll('[data-order-items-target="partsList"] [data-order-items-target="row"]')
    ).toHaveLength(0);
    expect(total()).toBe('R$ 0,00');
  });
});
