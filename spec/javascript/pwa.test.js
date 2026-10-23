import { describe, expect, it } from 'bun:test';
import { registerServiceWorker } from '../../app/javascript/pwa';

describe('registerServiceWorker', () => {
  it('registers the service worker at the root scope', async () => {
    const calls = [];
    const nav = { serviceWorker: { register: async (...args) => calls.push(args) } };

    await registerServiceWorker(nav);

    expect(calls).toEqual([['/service-worker', { scope: '/' }]]);
  });

  it('does nothing when the browser has no service worker support', () => {
    expect(registerServiceWorker({})).toBeNull();
  });

  it('swallows a failed registration', async () => {
    const nav = { serviceWorker: { register: () => Promise.reject(new Error('insecure')) } };

    expect(await registerServiceWorker(nav)).toBeNull();
  });
});
