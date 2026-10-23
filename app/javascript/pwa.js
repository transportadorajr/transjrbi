export function registerServiceWorker(nav = navigator) {
  if (!('serviceWorker' in nav)) return null;

  return nav.serviceWorker.register('/service-worker', { scope: '/' }).catch(() => null);
}
