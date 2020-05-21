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
var muted = false;
try {
  muted = JSON.parse(localStorage.getItem("session.muted") || "false");
} catch (e) {
  Sentry.captureException(e);
}

var app = Elm.App.init({
  node: document.body,
  flags: {
    version: version ? version.substr(0, 7) : "dev",
    token: token || null,
    isTelegram: isTelegram,
    screenshot: /[?&]screenshot/.test(window.location.search),
    notificationsEnabled: notificationsEnabled,
    muted: muted,
    zip: !!zip,
  },
});

app.ports.started.subscribe(function(msg) {
  window.dialogPolyfill = require("dialog-polyfill");
});

app.ports.saveToken.subscribe(function(token) {
  try {
    if (token !== null) {
      localStorage.setItem("jwt_token", token);
    } else {
      localStorage.removeItem("jwt_token");
    }
  } catch (e) {
    Sentry.captureException(e);
  }
});

app.ports.consoleDebug.subscribe(function(string) {
  var lines = string.split("\n");
  if (lines.length === 1) {
    console.debug(lines[0]);
  } else {
    console.groupCollapsed(lines.shift());
    console.debug(lines.join("\n"));
    console.groupEnd();
  }
});

var snackbar = function(options) {
  try {
    var snackbar = require("./snackbar");
    snackbar.show(options);
  } catch (e) {
    console.error(e);
    Sentry.captureException(e);
  }
};
app.ports.toast.subscribe(function(options) {
  snackbar(
    Object.assign(options, {
      pos: "bottom-center",
      actionTextColor: "#38d6ff",
      actionText: "Ok",
    })
  );
});

app.ports.sentry.subscribe(function(message) {
  if (Sentry) {
    Sentry.captureMessage(message);
  } else {
    console.error("Sentry not loaded:", message);
  }
});

var sounds = require("./sounds");
app.ports.playSound.subscribe(sounds.play);

const favicon = require("./favicon");
app.ports.notification.subscribe(function(event) {
  switch (event) {
    case "game-start":
      favicon("alert");
      notification("The game started", [], event);
      break;
    case "game-turn":
      favicon("alert");
      notification("It's your turn!", [], event);
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
      snackbar({
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
        snackbar({
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
    snackbar({
      text:
        'It seems that you have blocked notifications at some time before. Try clicking on the lock icon next to the URL and look for "Notifications" or "Permissions" and unblock it.',
      pos: "bottom-center",
      actionTextColor: "#38d6ff",
      duration: 15000,
    });
  }
});

app.ports.renounceNotifications.subscribe(function(jwt) {
  if (!navigator || !navigator.serviceWorker) {
    return;
  }
  navigator.serviceWorker.ready.then(function(registration) {
    return registration.pushManager
      .getSubscription()
      .then(function(subscription) {
        try {
          localStorage.removeItem("notifications");
          app.ports.notificationsChange.send([
            "denied",
            JSON.stringify(subscription),
            jwt,
          ]);
        } catch (e) {
          Sentry.captureException(e);
        }
      });
  });
});

function enablePush() {
  try {
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
  } catch (e) {
    Sentry.captureException(e);
  }
}

function notification(title, actions, tag) {
  try {
    if (
      localStorage.getItem("notifications") === "2" &&
      "Notification" in window &&
      Notification.permission === "granted" &&
      serviceWorkerRegistration !== null &&
      typeof document.visibilityState !== "undefined" &&
      document.visibilityState === "hidden"
    ) {
      serviceWorkerRegistration
        .getNotifications()
        .then(function(notifications) {
          notifications.forEach(function(notification) {
            notification.close();
          });

          return serviceWorkerRegistration.showNotification(title, {
            icon: "https://qdice.wtf/favicons-2/android-chrome-512x512.png",
            badge: "https://qdice.wtf/assets/monochrome.png",
            actions: actions,
            vibrate: [50, 100, 50],
            tag: tag,
          });
        })
        .then(function() {
          return serviceWorkerRegistration
            .getNotifications()
            .then(function(notifications) {
              return new Promise(function(resolve) {
                setTimeout(function() {
                  notifications.forEach(function(notification) {
                    notification.close();
                  });
                  resolve();
                }, 10000);
              });
            });
        });
    }
  } catch (e) {
    console.error(e);
    if (Sentry) {
      Sentry.captureException(e);
    }
  }
}

navigator.serviceWorker.addEventListener("message", function(event) {
  if (event.data.msg === "notification-click") {
    app.ports.notificationClick.send(event.data.tag);
  } else if (event.data.msg === "notification") {
    app.ports.pushNotification.send(event.data.json);
  }
});
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

app.ports.setSessionPreference.subscribe(function(keyValue) {
  try {
    localStorage.setItem("session." + keyValue[0], keyValue[1]);
  } catch (e) {
    Sentry.captureException(e);
  }
});
