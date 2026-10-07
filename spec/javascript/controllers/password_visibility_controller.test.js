import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import { Application } from '@hotwired/stimulus';
import PasswordVisibilityController from '../../../app/javascript/controllers/password_visibility_controller';

const tick = () => new Promise(resolve => setTimeout(resolve, 0));

const fieldHtml = `
  <div data-controller="password-visibility">
    <input type="password" data-password-visibility-target="input">
    <button type="button" aria-pressed="false" data-password-visibility-target="button"
            data-action="password-visibility#toggle">
      <i class="bi bi-eye" data-password-visibility-target="icon"></i>
    </button>
  </div>
`;

describe('PasswordVisibilityController', () => {
  let application;

  const input = () => document.querySelector('input');
  const button = () => document.querySelector('button');
  const icon = () => document.querySelector('i');

  beforeEach(async () => {
    document.body.innerHTML = fieldHtml;
    application = Application.start();
    application.register('password-visibility', PasswordVisibilityController);
    await tick();
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  it('reveals the password on the first click', () => {
    button().click();

    expect(input().type).toBe('text');
    expect(button().getAttribute('aria-pressed')).toBe('true');
    expect(icon().classList.contains('bi-eye-slash')).toBe(true);
    expect(icon().classList.contains('bi-eye')).toBe(false);
  });

  it('hides the password again on the second click', () => {
    button().click();
    button().click();

    expect(input().type).toBe('password');
    expect(button().getAttribute('aria-pressed')).toBe('false');
    expect(icon().classList.contains('bi-eye')).toBe(true);
    expect(icon().classList.contains('bi-eye-slash')).toBe(false);
  });

  it('keeps the focus on the password field', () => {
    button().click();

    expect(document.activeElement).toBe(input());
  });
});
