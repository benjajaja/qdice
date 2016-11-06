'use strict';

require('./index.html');
require('../src/Stylesheets');
require('muicss/dist/css/mui.css');
require('muicss/dist/js/mui.js');

var Elm = require('../src/App');

// document.body.innerHTML = '';
var app = Elm.Edice.fullscreen();
app.ports.hide.subscribe(function(msg) {
  document.getElementById('loading-indicator').remove();
});
