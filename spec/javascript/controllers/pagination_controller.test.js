import { afterEach, beforeEach, describe, expect, it } from 'bun:test';
import { Application } from '@hotwired/stimulus';
import PaginationController from '../../../app/javascript/controllers/pagination_controller';

const tick = (ms = 0) => new Promise(resolve => setTimeout(resolve, ms));

const paginator = page => `
  <nav data-controller="pagination" data-action="click->pagination#remember">
    <ul class="pagination">
      <li class="page-item active"><span class="page-link" aria-current="page">1</span></li>
      <li class="page-item"><a class="page-link" id="${page}_link" href="/macro_regions?${page}=2">2</a></li>
      <li class="page-item"><a class="page-link" id="${page}_anchor_link" href="/macro_regions?${page}=2#table">2</a></li>
    </ul>
  </nav>
`;

const html = `
  <div class="card table-card" id="first_card">${paginator('page')}</div>
  <div class="card table-card" id="second_card">${paginator('groups_page')}</div>
`;

const preventNavigation = event => event.preventDefault();

describe('PaginationController', () => {
  let application;
  let scrolled;

  const element = id => document.getElementById(id);
  const stored = () => JSON.parse(window.sessionStorage.getItem('pagination:scroll'));

  const start = async () => {
    document.body.innerHTML = html;
    scrolled = [];
    document.querySelectorAll('.card').forEach(card => {
      card.scrollIntoView = () => scrolled.push(card.id);
    });
    application = Application.start();
    application.register('pagination', PaginationController);
    await tick();
  };

  const visit = async url => {
    application.stop();
    window.history.replaceState({}, '', url);
    await start();
    document.dispatchEvent(new Event('turbo:load'));
  };

  beforeEach(async () => {
    document.addEventListener('click', preventNavigation);
    window.sessionStorage.clear();
    window.history.replaceState({}, '', '/macro_regions');
    await start();
  });

  afterEach(() => {
    document.removeEventListener('click', preventNavigation);
    application.stop();
    document.body.innerHTML = '';
    window.sessionStorage.clear();
  });

  it('remembers the page and the paginator that was clicked', () => {
    element('groups_page_link').click();

    expect(stored()).toEqual({ url: 'http://app.localhost/macro_regions?groups_page=2', index: 1 });
  });

  it('scrolls to the card of the clicked paginator once the next page loads', async () => {
    element('groups_page_link').click();
    await visit('/macro_regions?groups_page=2');

    expect(scrolled).toEqual(['second_card']);
    expect(stored()).toBeNull();
  });

  it('scrolls to the first card when its paginator was clicked', async () => {
    element('page_link').click();
    await visit('/macro_regions?page=2');

    expect(scrolled).toEqual(['first_card']);
  });

  it('does not scroll when another page is loaded', async () => {
    element('page_link').click();
    await visit('/customers');

    expect(scrolled).toEqual([]);
  });

  it('leaves a link with an anchor to Turbo', async () => {
    element('page_anchor_link').click();

    expect(stored()).toBeNull();
  });
});
