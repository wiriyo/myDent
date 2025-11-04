// Minimal service worker to satisfy Flutter bootstrap while keeping caching disabled.
self.addEventListener('install', (event) => {
  // Activate immediately without waiting for older versions.
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

// Do not intercept fetch requests; allow the browser to handle everything.
self.addEventListener('fetch', () => {});
