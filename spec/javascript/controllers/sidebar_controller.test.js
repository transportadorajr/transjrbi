import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import { Application } from '@hotwired/stimulus';
import SidebarController from '../../../app/javascript/controllers/sidebar_controller';

const tick = () => new Promise(resolve => setTimeout(resolve, 0));

const layoutHtml = `
  <div data-controller="sidebar">
    <button type="button" data-action="sidebar#toggle" data-sidebar-target="toggleBtn"></button>
    <div id="sidebar" data-sidebar-target="desktop"></div>
  </div>
`;

describe('SidebarController', () => {
  let application;

  const button = () => document.querySelector('button');
  const sidebar = () => document.querySelector('#sidebar');

  const mount = async () => {
    document.body.innerHTML = layoutHtml;
    application = Application.start();
    application.register('sidebar', SidebarController);
    await tick();
  };

  beforeEach(() => {
    localStorage.clear();
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  it('starts expanded when nothing was saved', async () => {
    await mount();

    expect(sidebar().classList.contains('sidebar-collapsed')).toBe(false);
    expect(button().classList.contains('is-active')).toBe(false);
  });

  it('collapses the sidebar and remembers it on the first click', async () => {
    await mount();

    button().click();

    expect(sidebar().classList.contains('sidebar-collapsed')).toBe(true);
    expect(button().classList.contains('is-active')).toBe(true);
    expect(localStorage.getItem('transjrbi_sidebar_collapsed')).toBe('true');
  });

  it('expands the sidebar again on the second click', async () => {
    await mount();

    button().click();
    button().click();

    expect(sidebar().classList.contains('sidebar-collapsed')).toBe(false);
    expect(button().classList.contains('is-active')).toBe(false);
    expect(localStorage.getItem('transjrbi_sidebar_collapsed')).toBe('false');
  });

  it('restores the collapsed state saved on a previous visit', async () => {
    localStorage.setItem('transjrbi_sidebar_collapsed', 'true');

    await mount();

    expect(sidebar().classList.contains('sidebar-collapsed')).toBe(true);
    expect(button().classList.contains('is-active')).toBe(true);
  });
});
