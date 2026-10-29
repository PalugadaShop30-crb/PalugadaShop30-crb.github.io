const CACHE_NAME = 'palugada-shell-v20261030-0540';

self.addEventListener('install', event => {
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter(key => key.startsWith('palugada-shell-') && key !== CACHE_NAME).map(key => caches.delete(key)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (request.mode === 'navigate' && url.origin === self.location.origin) {
    event.respondWith((async () => {
      try {
        // Bypass browser HTTP cache for every document navigation.
        return await fetch(new Request(request, { cache: 'reload' }));
      } catch (error) {
        const cached = await caches.match(request);
        if (cached) return cached;
        return new Response('Koneksi gagal. Silakan muat ulang halaman.', {
          status: 503,
          headers: { 'Content-Type': 'text/plain; charset=utf-8' }
        });
      }
    })());
  }
});
