'use strict';

require('./index.html');
require('./elm-dice.css');

var Elm = require('../src/App');

var app = Elm.Edice.fullscreen();
app.ports.hide.subscribe(function(msg) {
  document.getElementById('loading-indicator').remove();
});

app.ports.queryWidth.subscribe(function(id) {
  setTimeout(function() {
    app.ports.width.send(document.getElementById(id).clientWidth);
  }, 0);
});

app.ports.selectAll.subscribe(function(id) {
  var selection = window.getSelection();
  var range = document.createRange();
  range.selectNodeContents(document.getElementById(id));
  selection.removeAllRanges();
  selection.addRange(range);
});

global.edice = app;

window.onerror = function(messageOrEvent, source, lineno, colno, error) {
  window.alert(messageOrEvent.toString());
  return false; // let built in handler log it too
}