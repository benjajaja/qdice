"use strict";
if (location.hostname !== "localhost") {
  var Sentry = require("@sentry/browser");
  Sentry.init({
    dsn: "https://5658c32b571244958da8195b723bf5cb@sentry.io/1862179",
    release: typeof version === "string" ? version.substr(0, 7) : "dev",
  });
}

// window.onerror = function(messageOrEvent, source, lineno, colno, error) {
// var element = document.createElement("div");
// element.innerHTML = messageOrEvent.toString();
// element.className = "GLOBAL_ERROR";
// document.body.append(element);
// return false; // let built in handler log it too
// };

if (window.navigator.standalone === true) {
  var fragment = document.createElement("div");
  fragment.style.height = "10px";
  fragment.style.background = "#2196f3";
  document.body.insertBefore(fragment, document.body.childNodes[0]);
  // mobile app
  document.body.classList.add("navigator-standalone");
  document.addEventListener("contextmenu", function(event) {
    event.preventDefault();
  });
  var viewportmeta = document.querySelector('meta[name="viewport"]');
  viewportmeta.content =
    "user-scalable=NO, width=device-width, initial-scale=1.0";
}

var ga = function() {};

var Elm = require("../src/App").Elm;

var isTelegram = typeof TelegramWebviewProxy === "object";
var token = null;
try {
  if (window.location.hash.indexOf("#access_token=") !== 0) {
    token = localStorage.getItem("jwt_token");
  }
} catch (e) {
  Sentry.captureException(e);
}

var notificationsEnabled = false;
if ("Notification" in window) {
  try {
    notificationsEnabled =
      Notification.permission === "granted" &&
      localStorage.getItem("notifications") === "2";
  } catch (e) {
    Sentry.captureException(e);
  }
}

var app = Elm.App.init({
  node: document.body,
  flags: {
    version: version ? version.substr(0, 7) : "dev",
    token: token || null,
    isTelegram: isTelegram,
    screenshot: /[?&]screenshot/.test(window.location.search),
    notificationsEnabled: notificationsEnabled,
    muted: JSON.parse(localStorage.getItem("session.muted") || "false"),
    zip: !!zip,
  },
});

app.ports.started.subscribe(function(msg) {
  window.dialogPolyfill = require("dialog-polyfill");
});

app.ports.saveToken.subscribe(function(token) {
  if (token !== null) {
    localStorage.setItem("jwt_token", token);
  } else {
    localStorage.removeItem("jwt_token");
  }
});

app.ports.consoleDebug.subscribe(function(string) {
  var lines = string.split("\n");
  console.groupCollapsed(lines.shift());
  console.debug(lines.join("\n"));
  console.groupEnd();
});

var snackbar = require("node-snackbar/dist/snackbar.min.js");
app.ports.toast.subscribe(function(options) {
  snackbar.show(
    Object.assign(options, {
      pos: "bottom-center",
      actionTextColor: "#38d6ff",
      actionText: "Ok",
    })
  );
});

var sounds = require("./sounds");
app.ports.playSound.subscribe(sounds.play);

const favicon = require("./favicon");
app.ports.notification.subscribe(function(event) {
  switch (event) {
    case "game-start":
      favicon("alert");
      notification("The game started", []);
      break;
    case "game-turn":
      favicon("alert");
      notification("It's your turn!", []);
    case null:
    default:
      favicon("");
  }
});

app.ports.mqttConnect.subscribe(function(jwt) {
  var mqtt = require("./elm-dice-mqtt.js");

  mqtt.onmessage = function(action) {
    if (!app.ports[action.type]) {
      console.error("no port", action);
    } else {
      app.ports[action.type].send(action.payload);
    }
  };
  mqtt.connect(jwt);
  app.ports.mqttSubscribe.subscribe(mqtt.subscribe);
  app.ports.mqttUnsubscribe.subscribe(mqtt.unsubscribe);
  app.ports.mqttPublish.subscribe(mqtt.publish);
});

app.ports.ga.subscribe(function(args) {
  ga.apply(null, args);
});

global.edice = app;

app.ports.requestFullscreen.subscribe(function() {
  if (!document.fullscreenElement) {
    document.documentElement.requestFullscreen();
  } else {
    if (document.exitFullscreen) {
      document.exitFullscreen();
    }
  }
});
if (screen && screen.orientation) {
  window.addEventListener("orientationchange", function() {
    if (screen.orientation.angle !== 90 && document.fullscreenElement) {
      document.exitFullscreen();
    }
  });
}

var logPublish = function(args) {
  try {
    var topic = args[0];
    var message = args[1];
    var json = JSON.parse(message);
    ga("send", "event", "game", json.type, topic);
    switch (json.type) {
      case "Enter":
        break;
    }
  } catch (e) {
    console.error("could not log pub", e);
  }
};

var serviceWorkerRegistration = null;
if ("serviceWorker" in navigator) {
  navigator.serviceWorker
    .register("./elm-dice-serviceworker.js", { scope: "." })
    .then(function(registration) {
      // registration worked
      serviceWorkerRegistration = registration;
    })
    .catch(function(error) {
      // registration failed
      console.log("Registration failed with " + error);
    });
}

app.ports.requestNotifications.subscribe(function() {
  if (!("Notification" in window)) {
    app.ports.notificationsChange.send(["unsupported", null, null]);
    window.alert("This browser or system does not support notifications.");
    console.log("No notification support");
    return;
  }
  if (Notification.permission === "granted") {
    enablePush().then(function(subscription) {
      app.ports.notificationsChange.send([
        "granted",
        JSON.stringify(subscription),
        null,
      ]);
      snackbar.show({
        text: "Notifications are enabled",
        pos: "bottom-center",
        actionTextColor: "#38d6ff",
      });
    });
  } else if (Notification.permission !== "denied") {
    Notification.requestPermission(function(permission) {
      enablePush().then(function(subscription) {
        app.ports.notificationsChange.send([
          permission,
          JSON.stringify(subscription),
          null,
        ]);
        snackbar.show({
          text:
            permission === "granted"
              ? "Notifications are now enabled"
              : "Huh? It looks like you didn't allow notifications. Please try again.",
          pos: "bottom-center",
          actionTextColor: "#38d6ff",
        });
      });
    });
  } else if (Notification.permission === "denied") {
    app.ports.notificationsChange.send(["denied", null, null]);
    snackbar.show({
      text:
        'It seems that you have blocked notifications at some time before. Try clicking on the lock icon next to the URL and look for "Notifications" or "Permissions" and unblock it.',
      pos: "bottom-center",
      actionTextColor: "#38d6ff",
      duration: 15000,
    });
  }
});

app.ports.renounceNotifications.subscribe(function(jwt) {
  navigator.serviceWorker.ready.then(function(registration) {
    return registration.pushManager
      .getSubscription()
      .then(function(subscription) {
        localStorage.removeItem("notifications");
        app.ports.notificationsChange.send([
          "denied",
          JSON.stringify(subscription),
          jwt,
        ]);
      });
  });
});

function enablePush() {
  localStorage.setItem("notifications", "2");
  return navigator.serviceWorker.ready
    .then(function(registration) {
      return registration.pushManager
        .getSubscription()
        .then(function(subscription) {
          if (subscription) {
            return subscription;
          }

          return new Promise(function(resolve) {
            app.ports.pushGetKey.send(null);
            app.ports.pushSubscribe.subscribe(function(vapidPublicKey) {
              const convertedVapidKey = urlBase64ToUint8Array(vapidPublicKey);
              resolve(
                registration.pushManager.subscribe({
                  userVisibleOnly: true,
                  applicationServerKey: convertedVapidKey,
                })
              );
            });
          });
        });
    })
    .then(function(subscription) {
      app.ports.pushRegister.send(JSON.stringify(subscription));
      return subscription;
    })
    .catch(function(error) {
      console.error("Error while subscribing push:", error);
    });
}

function notification(title, actions) {
  if (
    localStorage.getItem("notifications") === "1" &&
    "Notification" in window &&
    Notification.permission === "granted" &&
    serviceWorkerRegistration !== null &&
    typeof document.visibilityState !== "undefined" &&
    document.visibilityState === "hidden"
  ) {
    var notification = serviceWorkerRegistration.showNotification(title, {
      icon: "https://qdice.wtf/favicons-2/android-chrome-512x512.png",
      badge: "https://qdice.wtf/assets/monochrome.png",
      actions: actions,
      vibrate: [50, 100, 50],
    });
    notification.onclick = function(event) {
      event.preventDefault();
      notification.close();
    };
  }
}

function urlBase64ToUint8Array(base64String) {
  var padding = "=".repeat((4 - (base64String.length % 4)) % 4);
  var base64 = (base64String + padding).replace(/\-/g, "+").replace(/_/g, "/");

  var rawData = window.atob(base64);
  var outputArray = new Uint8Array(rawData.length);

  for (var i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i);
  }
  return outputArray;
}

try {
  if (localStorage.getItem("notifications") === "1") {
    // this was a hotfix in production
    snackbar.show({
      text: 'Please click "Enable notifications" one more time',
      pos: "bottom-center",
      actionTextColor: "#38d6ff",
    });
  }
} catch (e) {
  Sentry.captureException(e);
}

app.ports.setSessionPreference.subscribe(function(keyValue) {
  localStorage.setItem("session." + keyValue[0], keyValue[1]);
});
