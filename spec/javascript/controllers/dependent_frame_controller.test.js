import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import { Application } from '@hotwired/stimulus';
import DependentFrameController from '../../../app/javascript/controllers/dependent_frame_controller';

const tick = (ms = 0) => new Promise(resolve => setTimeout(resolve, ms));

const html = `
  <div data-controller="dependent-frame" data-dependent-frame-url-value="/options"
       data-dependent-frame-param-value="group_id" data-dependent-frame-selected-param-value="code">
    <div data-action="change->dependent-frame#reload">
      <input type="hidden" id="group" name="group_id">
      <input type="search" id="search">
    </div>
    <div id="frame" data-dependent-frame-target="frame">
      <input type="hidden" name="code" value="7200">
    </div>
  </div>
`;

describe('DependentFrameController', () => {
  let application;

  const frame = () => document.getElementById('frame');
  const change = (id, value) => {
    const input = document.getElementById(id);
    input.value = value;
    input.dispatchEvent(new Event('change', { bubbles: true }));
  };

  beforeEach(async () => {
    document.body.innerHTML = html;
    application = Application.start();
    application.register('dependent-frame', DependentFrameController);
    await tick();
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  it('reloads the frame with the new value and the current selection', () => {
    change('group', '5');

    expect(frame().src).toBe('/options?group_id=5&code=7200');
  });

  it('reloads the frame without a value when the parent is cleared', () => {
    change('group', '');

    expect(frame().src).toBe('/options?group_id=&code=7200');
  });

  it('ignores the change event of the search field', () => {
    change('search', 'usi');

    expect(frame().src).toBeUndefined();
  });
});
