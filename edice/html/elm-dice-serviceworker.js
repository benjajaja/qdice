var CACHE = "cache2";

// INSTALL

self.addEventListener("install", function(evt) {
  evt.waitUntil(preCache());
});
self.addEventListener("activate", function(event) {
  event.waitUntil(self.clients.claim());
});

// PUSH
function getEndpoint() {
  // TODO what is the purpose of this?
  return self.registration.pushManager
    .getSubscription()
    .then(function(subscription) {
      if (subscription) {
        return subscription.endpoint;
      }

      throw new Error("User not subscribed");
    });
}

/**
 * Try to only show the last push as a notification.
 * Otherwise user might get like 10 notifications at the same time,
 * e.g. when he reconnects or the browser does its SW throttling magic.
 */
var queue = [];
function pushQueue(json) {
  return new Promise(function(resolve) {
    queue.push(json);
    setTimeout(resolve, 1000);
  }).then(function() {
    var json = queue.pop();
    if (json) {
      self.registration.showNotification(json.text, {
        icon: "https://qdice.wtf/favicons-2/android-chrome-512x512.png",
        badge: "https://qdice.wtf/assets/monochrome.png",
        vibrate: [50, 100, 50],
        data: json,
      });
      queue = [];
    }
  });
}

self.addEventListener("push", function(event) {
  var json = JSON.parse(event.data.text());
  event.waitUntil(pushQueue(json));
});

// CACHE

function preCache() {
  return caches
    .open(CACHE)
    .then(function(cache) {
      return fetch("mapnames.json")
        .then(function(response) {
          return response.json();
        })
        .then(function(maps) {
          var files = maps
            .concat([
              "./",
              "./die.svg",
              "./favicons-2/favicon.png",
              "./iconfont/MaterialIcons-Regular.woff2",
              "./fonts/rubik-v7-latin-regular.woff2",
              "./fonts/rubik-v7-latin-500.woff2",
            ])
            .concat(
              [
                "kick",
                "start",
                "finish",
                "turn",
                "diceroll",
                "rollSuccess",
                "rollDefeat",
              ].map(function(name) {
                return "./sounds/" + name + ".ogg";
              })
            );
          return cache.addAll(files);
        });
    })
    .then(function() {
      return self.skipWaiting();
    })
    .catch(function(err) {
      console.error("preCache", err);
    });
}
var hostname = new URL(self.registration.scope).hostname;
self.addEventListener("fetch", function(event) {
  var url = new URL(event.request.url);
  var path = url.pathname;
  var destination = event.request.destination;
  // console.log(destination, typeof destination, path);
  /* We should only cache GET requests, and deal with the rest of method in the
     client-side, by handling failed POST,PUT,PATCH,etc. requests.
  */
  if (
    hostname === "localhost" ||
    destination === "" ||
    path.indexOf("/api") === 0 ||
    /elm-dice\..*\.{css|js}/.test(path) ||
    event.request.method !== "GET"
    // ["style", "script", "document" , "image", "font"].indexOf(
    // destination
    // ) === -1
  ) {
    /* If we don't block the event as shown below, then the request will go to
       the network as usual.
    */
    return;
  }
  if (destination === "document") {
    var request = event.request;
    var fetchThenCache = new Promise(function(resolve, reject) {
      var timeoutId = setTimeout(reject, 1000);
      fetch(request).then(function(response) {
        clearTimeout(timeoutId);
        resolve(response);
      }, reject);
    }).catch(function() {
      return caches.open(CACHE).then(function(cache) {
        return cache.match(request).then(function(matching) {
          return (
            matching ||
            Promise.reject("offline and no cache for " + destination)
          );
        });
      });
    });
    event.respondWith(fetchThenCache);
    return;
  }
  // console.log("network then cache", path);
  /* Similar to event.waitUntil in that it blocks the fetch event on a promise.
     Fulfillment result will be used as the response, and rejection will end in a
     HTTP response indicating failure.
  */
  event.respondWith(
    caches
      /* This method returns a promise that resolves to a cache entry matching
         the request. Once the promise is settled, we can then provide a response
         to the fetch request.
      */
      .match(event.request)
      .then(function(cached) {
        /* Even if the response is in our cache, we go to the network as well.
           This pattern is known for producing "eventually fresh" responses,
           where we return cached responses immediately, and meanwhile pull
           a network response and store that in the cache.
           Read more:
           https://ponyfoo.com/articles/progressive-networking-serviceworker
        */
        var networked = fetch(event.request)
          // We handle the network request with success and failure scenarios.
          .then(fetchedFromNetwork, unableToResolve)
          // We should catch errors on the fetchedFromNetwork handler as well.
          .catch(unableToResolve);

        /* We return the cached response immediately if there is one, and fall
           back to waiting on the network as usual.
        */
        // console.log(
        // "WORKER: fetch event",
        // cached ? "(cached)" : "(network)",
        // event.request.url
        // );
        return cached || networked;

        function fetchedFromNetwork(response) {
          /* We copy the response before replying to the network request.
             This is the response that will be stored on the ServiceWorker cache.
          */
          var cacheCopy = response.clone();

          // console.log(
          // "WORKER: fetch response from network.",
          // event.request.url
          // );

          caches
            // We open a cache to store the response for this request.
            .open(CACHE)
            .then(function add(cache) {
              /* We store the response for this request. It'll later become
                 available to caches.match(event.request) calls, when looking
                 for cached responses.
              */
              cache.put(event.request, cacheCopy);
            })
            .then(function() {
              // console.log(
              // "WORKER: fetch response stored in cache.",
              // event.request.url
              // );
            });

          // Return the response so that the promise is settled in fulfillment.
          return response;
        }

        /* When this method is called, it means we were unable to produce a response
           from either the cache or the network. This is our opportunity to produce
           a meaningful response even when all else fails. It's the last chance, so
           you probably want to display a "Service Unavailable" view or a generic
           error response.
        */
        function unableToResolve(err) {
          /* There's a couple of things we can do here.
             - Test the Accept header and then return one of the `offlineFundamentals`
               e.g: `return caches.match('/some/cached/image.png')`
             - You should also consider the origin. It's easier to decide what
               "unavailable" means for requests against your origins than for requests
               against a third party, such as an ad provider
             - Generate a Response programmaticaly, as shown below, and return that
          */

          // console.log(
          // "WORKER: fetch request failed in both cache and network.",
          // err
          // );

          /* Here we're creating a response programmatically. The first parameter is the
             response body, and the second one defines the options for the response.
          */
          return new Response("<h1>Service Unavailable</h1>", {
            status: 503,
            statusText: "Service Unavailable",
            headers: new Headers({
              "Content-Type": "text/html",
            }),
          });
        }
      })
  );
});

// NOTIFICATIONS

self.onnotificationclick = function(event) {
  console.log("On notification click: ", event.notification.tag);
  event.notification.close();

  // This looks to see if the current is already open and
  // focuses if it is
  event.waitUntil(
    clients
      .matchAll({
        type: "window",
      })
      .then(function(clientList) {
        var url = event.notification.data ? event.notification.data.link : null;
        for (var i = 0; i < clientList.length; i++) {
          var client = clientList[i];
          if ("focus" in client) {
            client.focus();
            if (url) {
              client.navigate(url);
            }
            client.postMessage({
              msg: "notification-click",
              tag: event.notification.tag,
            });
            return;
          }
        }
        if (clients.openWindow) {
          return clients.openWindow(url || "/");
        }
      })
  );
};
