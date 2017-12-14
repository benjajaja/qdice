console.log("SW startup");

require('./elm-dice-webworker');

self.addEventListener('install', function(event) {
  console.log("SW installed");
  event.waitUntil(self.skipWaiting()); // Activate worker immediately
  //event.waitUntil(caches.open('edice').then(function(cache) {
    //return cache.addAll([
      //'/',
      //'/index.html',
      //'/index.html?homescreen=1',
      //'/?homescreen=1',
      //'/elm-dice.css',
      //'/elm-dice.js',
      //'/cache-polyfill.js',
    //]);
  //}));
});

//self.addEventListener('fetch', function(event) {
  //event.respondWith(
    //caches.match(event.request).then(function(response) {
      //if (response) {
        //console.log('service worker cache', event.request.url);
      //}
      //return response || fetch(event.request);
    //})
  //);
//});

self.addEventListener('activate', function(event) {
  console.log("SW activated");
  event.waitUntil(self.clients.claim()); // Become available to all pages
});

importScripts('/cache-polyfill.js');

//self.addEventListener('fetch', function(event) {
  //console.log("Caught a fetch!");
  //event.respondWith(new Response("Hello world!"));
//});
