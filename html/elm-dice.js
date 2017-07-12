'use strict';

window.onerror = function(messageOrEvent, source, lineno, colno, error) {
  var element = document.createElement('div');
  element.innerHTML = messageOrEvent.toString();
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

var fastclick = require('fastclick');
document.addEventListener('DOMContentLoaded', function() {
  FastClick.attach(document.body);
}, false);

require('./auth.js')(function(profile) {
  app.ports.onLogin.send([profile.email || '', profile.name || '', profile.picture || '']);
});

var Elm = require('../src/App');

var app = Elm.Edice.fullscreen();

app.ports.hide.subscribe(function(msg) {
  document.getElementById('loading-indicator').remove();
  window.onerror = function(messageOrEvent, source, lineno, colno, error) {
    window.alert(messageOrEvent.toString());
    return false; // let built in handler log it too
  };
});

app.ports.selectAll.subscribe(function(id) {
  var selection = window.getSelection();
  var range = document.createRange();
  range.selectNodeContents(document.getElementById(id));
  selection.removeAllRanges();
  selection.addRange(range);
});

app.ports.consoleDebug.subscribe(function(string) {
  var lines = string.split('\n');
  console.groupCollapsed(lines.shift());
  console.debug(lines.join('\n'));
  console.groupEnd();
});



app.ports.mqttConnect.subscribe(function() {
  var Worker = require('worker-loader!./elm-dice-webworker.js');
  var worker = new Worker();
  worker.postMessage({type: 'connect', url: location.href});
  worker.addEventListener('message', function(event) {
    var action = event.data;
    app.ports[action.type].send(action.payload);
  });
  app.ports.mqttSubscribe.subscribe(function(args) {
    worker.postMessage({type: 'subscribe', payload: args});
  })
  app.ports.mqttPublish.subscribe(function(args) {
    worker.postMessage({type: 'publish', payload: args});
  })
});

app.ports.scrollChat.subscribe(function(id) {
  var element = document.getElementById(id);
  if (!element) return console.error('cannot scroll #' + id);
  var height = element.clientHeight;
  var scroll = element.scrollTop;
  var innerHeight = element.scrollHeight;
  if (innerHeight - scroll === height) {
    setTimeout(function() {
      element.scrollTop = innerHeight;
    }, 100);
  }
});

global.edice = app;
