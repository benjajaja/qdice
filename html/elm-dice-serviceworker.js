console.log("SW startup");

self.addEventListener('install', function(event) {
  console.log("SW installed");
});

self.addEventListener('activate', function(event) {
  console.log("SW activated");
});

//self.addEventListener('fetch', function(event) {
  //console.log("Caught a fetch!");
  //event.respondWith(new Response("Hello world!"));
//});
