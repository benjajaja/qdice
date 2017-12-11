console.log("SW startup");

self.addEventListener('install', function(event) {
  console.log("SW installed");
  event.waitUntil(caches.open('edice').then(function(cache) {
    return cache.addAll([
      '/',
      '/index.html',
      '/index.html?homescreen=1',
      '/?homescreen=1',
      '/elm-dice.css',
      '/elm-dice.js',
      '/cache-polyfill.js',
    ]);
  }));
});

self.addEventListener('fetch', function(event) {
  console.log('service worker fetch', event.request.url);
  event.respondWith(
    caches.match(event.request).then(function(response) {
      return response || fetch(event.request);
    })
  );
});

self.addEventListener('activate', function(event) {
  console.log("SW activated");
});

importScripts('/cache-polyfill.js');

//self.addEventListener('fetch', function(event) {
  //console.log("Caught a fetch!");
  //event.respondWith(new Response("Hello world!"));
//});
