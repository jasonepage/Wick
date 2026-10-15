// SPDX-License-Identifier: MPL-2.0
//
// Wick service worker (3.5). It exists so Android can install the web game as
// an app, and so a player with no connection sees a friendly page instead of
// the browser's error.
//
// It never caches the game itself. Every request goes to the network as usual,
// so a deploy is live on the next load. Only the offline page is cached, and
// only page loads ever fall back to it.

const CACHE = "wick-offline-v1";
const OFFLINE_URL = new URL("offline.html", self.registration.scope).href;

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.add(OFFLINE_URL)));
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener("fetch", (event) => {
  if (event.request.mode !== "navigate") return;
  event.respondWith(
    fetch(event.request).catch(() =>
      caches.match(OFFLINE_URL).then((page) => page || Response.error()),
    ),
  );
});
