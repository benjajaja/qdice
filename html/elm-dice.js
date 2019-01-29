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
  var Elm = require('../src/App').Elm;

  var isTelegram = (typeof TelegramWebviewProxy === 'object');
  var app = Elm.Edice.init({
    node: document.body,
    flags: {
      isTelegram: isTelegram,
    },
  });


  app.ports.started.subscribe(function(msg) {
    //document.getElementById('loading-indicator').remove();
    window.onerror = function(messageOrEvent, source, lineno, colno, error) {
      ga('send', 'exception', { exDescription: error.toString() });
      window.alert(messageOrEvent.toString());
      return false; // let built in handler log it too
    };
    window.dialogPolyfill = require('dialog-polyfill');

    if (window.location.hostname !== 'localhost' && window.location.hostname !== 'lvh.me') {
      ga = require('ga-lite');
      ga('create', 'UA-111861514-1', 'auto');
      ga('send', 'pageview');
    }
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

  //app.ports.consoleDebug.subscribe(function(string) {
    //var lines = string.split('\n');
    //console.groupCollapsed(lines.shift());
    //console.debug(lines.join('\n'));
    //console.groupEnd();
  //});

  app.ports.playSound.subscribe(require('./sounds'));
  app.ports.setFavicon.subscribe(require('./favicon'));


  app.ports.mqttConnect.subscribe(function() {
    var Worker = require('worker-loader!./elm-dice-webworker.js');
    var worker = new Worker();

    worker.postMessage({type: 'connect', url: location.href});
    worker.addEventListener('message', function(event) {
      var action = event.data;
      if (!app.ports[action.type]) {
        console.log('no port', action);
      }
      app.ports[action.type].send(action.payload);
    });
    app.ports.mqttSubscribe.subscribe(function(args) {
      worker.postMessage({type: 'subscribe', payload: args});
    });
    app.ports.mqttUnsubscribe.subscribe(function(args) {
      worker.postMessage({type: 'unsubscribe', payload: args});
    });
    app.ports.mqttPublish.subscribe(function(args) {
      worker.postMessage({type: 'publish', payload: args});
      logPublish(args);
    });
  });


  app.ports.ga.subscribe(function(args) {
    ga.apply(null, args);
  });

  global.edice = app;
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

