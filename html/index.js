'use strict';

require('./index.html');

var Elm = require('../src/App');

var app = Elm.Edice.fullscreen();
app.ports.hide.subscribe(function(msg) {
  document.getElementById('loading-indicator').remove();
});

app.ports.queryWidth.subscribe(function(id) {
  setTimeout(function() {
    app.ports.width.send(document.getElementById(id).clientWidth);
  }, 0);
})

global.edice = app;
