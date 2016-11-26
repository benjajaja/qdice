'use strict';

require('./index.html');

var Elm = require('../src/App');

var app = Elm.Edice.fullscreen();
app.ports.hide.subscribe(function(msg) {
  document.getElementById('loading-indicator').remove();
});
