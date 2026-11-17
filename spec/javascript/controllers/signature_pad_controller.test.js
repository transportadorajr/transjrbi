import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import { Application } from '@hotwired/stimulus';
import SignaturePadController from '../../../app/javascript/controllers/signature_pad_controller';

const tick = (ms = 0) => new Promise(resolve => setTimeout(resolve, ms));

const html = `
  <div id="pad" class="signature-pad" data-controller="signature-pad">
    <button type="button" id="undo" data-action="signature-pad#undo">Desfazer</button>
    <button type="button" id="clear" data-action="signature-pad#clear">Limpar</button>
    <canvas id="canvas" data-signature-pad-target="canvas"
            data-action="pointerdown->signature-pad#start pointermove->signature-pad#move pointerup->signature-pad#end pointercancel->signature-pad#end"></canvas>
    <input type="hidden" id="strokes" data-signature-pad-target="input" value="">
  </div>
`;

const pointer = (type, clientX, clientY) =>
  new MouseEvent(type, { bubbles: true, cancelable: true, clientX, clientY, button: 0 });

describe('SignaturePadController', () => {
  let application;

  const element = id => document.getElementById(id);

  const draw = points => {
    const [first, ...rest] = points;
    element('canvas').dispatchEvent(pointer('pointerdown', ...first));
    rest.forEach(point => element('canvas').dispatchEvent(pointer('pointermove', ...point)));
    element('canvas').dispatchEvent(pointer('pointerup', ...points[points.length - 1]));
  };

  const start = async value => {
    document.body.innerHTML = html;
    element('strokes').value = value;
    element('canvas').getBoundingClientRect = () => ({ left: 10, top: 20, width: 300, height: 100 });
    application = Application.start();
    application.register('signature-pad', SignaturePadController);
    await tick();
  };

  beforeEach(async () => {
    await start('');
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  it('stores each stroke as points relative to the pad', () => {
    draw([
      [40, 70],
      [160, 45],
      [310, 120],
    ]);

    expect(JSON.parse(element('strokes').value)).toEqual([
      [
        [0.1, 0.5],
        [0.5, 0.25],
        [1, 1],
      ],
    ]);
    expect(element('pad').classList.contains('signature-pad-signed')).toBe(true);
  });

  it('keeps the points inside the pad when the finger slides out of it', () => {
    draw([
      [0, 0],
      [400, 300],
    ]);

    expect(JSON.parse(element('strokes').value)).toEqual([
      [
        [0, 0],
        [1, 1],
      ],
    ]);
  });

  it('ignores the moves made before touching the pad', () => {
    element('canvas').dispatchEvent(pointer('pointermove', 40, 70));
    element('canvas').dispatchEvent(pointer('pointerup', 40, 70));

    expect(element('strokes').value).toBe('');
  });

  it('undoes the last stroke and clears the whole signature', () => {
    draw([
      [40, 70],
      [70, 70],
    ]);
    draw([
      [100, 70],
      [130, 70],
    ]);

    element('undo').click();

    expect(JSON.parse(element('strokes').value)).toEqual([
      [
        [0.1, 0.5],
        [0.2, 0.5],
      ],
    ]);

    element('clear').click();

    expect(element('strokes').value).toBe('');
    expect(element('pad').classList.contains('signature-pad-signed')).toBe(false);
  });

  it('keeps the signature already drawn when the form comes back with errors', async () => {
    application.stop();
    await start('[[[0.1,0.5],[0.2,0.5]]]');

    expect(element('pad').classList.contains('signature-pad-signed')).toBe(true);

    draw([
      [160, 70],
      [190, 70],
    ]);

    expect(JSON.parse(element('strokes').value)).toEqual([
      [
        [0.1, 0.5],
        [0.2, 0.5],
      ],
      [
        [0.5, 0.5],
        [0.6, 0.5],
      ],
    ]);
  });
});
