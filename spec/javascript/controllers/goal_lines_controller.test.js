import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import { Application } from '@hotwired/stimulus';
import GoalLinesController from '../../../app/javascript/controllers/goal_lines_controller';

const tick = (ms = 0) => new Promise(resolve => setTimeout(resolve, ms));

const html = `
  <form data-controller="goal-lines" data-action="input->goal-lines#refresh"
        data-goal-lines-unit-value="R$" data-goal-lines-separator-value="," data-goal-lines-delimiter-value="."
        data-goal-lines-share-value="{ratio} da meta da transportadora">
    <input id="company" value="200.000,00" data-goal-lines-target="company">
    <strong id="total" data-goal-lines-target="total" data-section="regions"></strong>
    <span id="share" data-goal-lines-target="share" data-section="regions"></span>
    <input id="search" data-action="input->goal-lines#filter" data-section="regions">
    <div id="vale" data-goal-lines-target="line" data-section="regions" data-name="VALE DO AÇO/MG">
      <input id="vale_amount" value="50.000,00" data-goal-lines-target="amount" data-section="regions">
    </div>
    <div id="bahia" data-goal-lines-target="line" data-section="regions" data-name="BAHIA">
      <input id="bahia_amount" value="" data-goal-lines-target="amount" data-section="regions">
    </div>
    <div id="plate" data-goal-lines-target="line" data-section="vehicles" data-name="AJR4391">
      <input id="plate_amount" value="1.000,00" data-goal-lines-target="amount" data-section="vehicles">
    </div>
  </form>
`;

describe('GoalLinesController', () => {
  let application;

  const element = id => document.getElementById(id);

  const typeInto = (id, value) => {
    element(id).value = value;
    element(id).dispatchEvent(new Event('input', { bubbles: true }));
  };

  beforeEach(async () => {
    document.body.innerHTML = html;
    application = Application.start();
    application.register('goal-lines', GoalLinesController);
    await tick();
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  it('sums the goals of the section when it connects', () => {
    expect(element('total').textContent).toBe('R$ 50.000,00');
    expect(element('share').textContent).toBe('25,0% da meta da transportadora');
  });

  it('updates the sum and the share as the goals are typed', () => {
    typeInto('bahia_amount', '1.234.567,89');
    expect(element('total').textContent).toBe('R$ 1.284.567,89');
    expect(element('share').textContent).toBe('642,3% da meta da transportadora');

    typeInto('company', '');
    expect(element('share').textContent).toBe('');
  });

  it('hides the lines of the section that do not match the search, ignoring accents', () => {
    typeInto('search', 'aco');

    expect(element('vale').classList.contains('d-none')).toBe(false);
    expect(element('bahia').classList.contains('d-none')).toBe(true);
    expect(element('plate').classList.contains('d-none')).toBe(false);

    typeInto('search', '');
    expect(element('bahia').classList.contains('d-none')).toBe(false);
  });
});
