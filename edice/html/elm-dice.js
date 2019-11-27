'use strict';

window.onerror = function(messageOrEvent, source, lineno, colno, error) {
  var element = document.createElement('div');
  element.innerHTML = messageOrEvent.toString();
  element.className = 'GLOBAL_ERROR';
  document.body.append(element);
  return false; // let built in handler log it too
};

if (window.navigator.standalone === true) {
  var fragment = document.createElement('div');
  fragment.style.height = '10px';
  fragment.style.background = '#2196f3';
  document.body.insertBefore(fragment, document.body.childNodes[0]);
  // mobile app
  document.body.classList.add('navigator-standalone');
  document.addEventListener('contextmenu', function (event) { event.preventDefault(); });
  var viewportmeta = document.querySelector('meta[name="viewport"]');
  viewportmeta.content = 'user-scalable=NO, width=device-width, initial-scale=1.0'
}

var ga = function(){};

setTimeout(function() {
  var Elm = require('../src/Edice').Elm;

  var isTelegram = (typeof TelegramWebviewProxy === 'object');
  var app = Elm.Edice.init({
    node: document.body,
    flags: {
      isTelegram: isTelegram,
      screenshot: /[?&]screenshot/.test(window.location.search),
    },
  });


  app.ports.started.subscribe(function(msg) {
    //document.getElementById('loading-indicator').remove();
    window.onerror = function(messageOrEvent, source, lineno, colno, error) {
      ga('send', 'exception', { exDescription: error.toString() });


      if (snackbar) {
        snackbar.show(
          Object.assign(options, {
            text: messageOrEvent.toString(),
            pos: 'bottom-center',
            actionTextColor: '#38d6ff',
          })
        );
      } else {
        window.alert(messageOrEvent.toString());
      }
      return false; // let built in handler log it too
    };
    window.dialogPolyfill = require('dialog-polyfill');

    //if (window.location.hostname !== 'localhost' && window.location.hostname !== 'lvh.me') {
      //ga = require('ga-lite');
      //ga('create', 'UA-111861514-1', 'auto');
      //ga('send', 'pageview');
    //}
  });


  if (window.location.hash.indexOf('#access_token=') !== 0) {
    var token = localStorage.getItem('jwt_token');
    if (token) {
      setTimeout(app.ports.onToken.send.bind(app.ports.onToken, token));
    }
  }
  app.ports.auth.subscribe(function(args) {
    if (args.length === 1) {
      localStorage.setItem('jwt_token', args);
    } else {
      localStorage.removeItem('jwt_token');
    }
  });

  //app.ports.selectAll.subscribe(function(id) {
    //var selection = window.getSelection();
    //var range = document.createRange();
    //range.selectNodeContents(document.getElementById(id));
    //selection.removeAllRanges();
    //selection.addRange(range);
  //});

  var scrollObservers = [];
  app.ports.scrollElement.subscribe(function(id) {
    var element = document.getElementById(id);
    if (!element) {
      return console.error('cannot autoscroll #' + id);
    }
    if (scrollObservers.indexOf(id) === -1) {
      try {
        var observer = new MutationObserver(function(mutationList) {
          mutationList.forEach(function(mutation) {
            var element = mutation.target;
            element.scrollTop = element.scrollHeight;
          });
        });
        if (element.scrollHeight - element.scrollTop === element.clientHeight) {
          observer.observe(element, { attributes: false, childList: true });
        }
        element.addEventListener('scroll', function() {
          if (element.scrollHeight - element.scrollTop === element.clientHeight) {
            observer.observe(element, { attributes: false, childList: true });
          } else {
            observer.disconnect();
          }
        });
        scrollObservers.push(id); 
      } catch (e) {
        console.error('autoscroll setup error', e);
      }
    }
  });

  app.ports.consoleDebug.subscribe(function(string) {
    var lines = string.split('\n');
    console.groupCollapsed(lines.shift());
    console.debug(lines.join('\n'));
    console.groupEnd();
  });

  var snackbar = require('node-snackbar/dist/snackbar.min.js');
  app.ports.toast.subscribe(function(options) {
    snackbar.show(Object.assign(options, {
      pos: 'bottom-center',
      actionTextColor: '#38d6ff',
    }));
  });

  var sounds = require('./sounds');
  app.ports.playSound.subscribe(sounds.play);
  app.ports.setFavicon.subscribe(require('./favicon'));


  app.ports.mqttConnect.subscribe(function() {
    var mqtt = require('./elm-dice-mqtt.js');

    mqtt.onmessage = function(action) {
      if (!app.ports[action.type]) {
        console.error('no port', action);
      } else {
        app.ports[action.type].send(action.payload);
      }
    };
    mqtt.connect(location.href);
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
  window.addEventListener('orientationchange', function() {
    if (screen.orientation.angle !== 90 && document.fullscreenElement) {
      document.exitFullscreen();
    }
  });
});

var logPublish = function(args) {
  try {
    var topic = args[0];
    var message = args[1];
    var json = JSON.parse(message);
    ga('send', 'event', 'game', json.type, topic);
    switch (json.type) {
      case 'Enter':
        break;
    }
  } catch (e) {
    console.error('could not log pub', e);
  }
};

