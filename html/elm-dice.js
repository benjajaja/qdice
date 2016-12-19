'use strict';

var Elm = require('../src/App');
var mqtt = require('mqtt');

var app = Elm.Edice.fullscreen();
app.ports.hide.subscribe(function(msg) {
  document.getElementById('loading-indicator').remove();
});

app.ports.selectAll.subscribe(function(id) {
  var selection = window.getSelection();
  var range = document.createRange();
  range.selectNodeContents(document.getElementById(id));
  selection.removeAllRanges();
  selection.addRange(range);
});

app.ports.consoleDebug.subscribe(function(string) {
  console.debug(string);
});



app.ports.mqttConnect.subscribe(function() {
  var url = 'ws://' + window.location.hostname + ':8080'
  var clientId = 'elm-dice_' + Math.random().toString(16).substr(2, 8);
  var client = mqtt.connect(url, {
    clientId: clientId,
  });
  client.on('connect', function (connack) {
    app.ports.mqttOnConnect.send(clientId);
  });

  client.on('message', function (topic, message) {
    app.ports.mqttOnMessage.send([topic, message.toString()]);
  });

  client.on('error', function (error) {
    console.error('mqtt error:', error);
  });

  app.ports.mqttSubscribe.subscribe(function(args) {
    client.subscribe(args, function(err, granted) {
      if (err) throw err;
      app.ports.mqttOnSubscribed.send(granted.shift().topic);
    });
  });

  app.ports.mqttPublish.subscribe(function(args) {
    client.publish(args[0], args[1]);
  });
});



global.edice = app;

window.onerror = function(messageOrEvent, source, lineno, colno, error) {
  window.alert(messageOrEvent.toString());
  return false; // let built in handler log it too
}