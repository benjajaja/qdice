'use strict';

window.onerror = function(messageOrEvent, source, lineno, colno, error) {
  var element = document.createElement('div');
  element.innerHTML = messageOrEvent.toString();
  document.body.append(element);
  return false; // let built in handler log it too
};

require('./auth.js')(function(profile) {
  app.ports.onLogin.send([profile.email || '', profile.name || '', profile.picture || '']);
});

var Elm = require('../src/App');
var mqtt = require('mqtt');

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
  console.debug(string);
});

var mqttConfig = {
  hostname: 'm21.cloudmqtt.com',
  port: 31201,
  username: 'client',
  password: 'client',
}

app.ports.mqttConnect.subscribe(function() {
  try {
    var url = 'wss://' + mqttConfig.hostname + ':' + mqttConfig.port;
    var clientId = 'elm-dice_' + Math.random().toString(16).substr(2, 8);
    var client = mqtt.connect(url, {
      clientId: clientId,
      username: mqttConfig.username,
      password: mqttConfig.password,
    });

    var connectionAttempts = 0;

    app.ports.mqttOnConnect.send('');

    client.on('connect', function (connack) {
      app.ports.mqttOnConnected.send(clientId);
      connectionAttempts = 0;
    });

    client.on('message', function (topic, message) {
      app.ports.mqttOnMessage.send([topic, message.toString()]);
    });

    client.on('error', function (error) {
      console.error('mqtt error:', error);
    });

    client.on('reconnect', function () {
      connectionAttempts = connectionAttempts + 1;
      app.ports.mqttOnReconnect.send(connectionAttempts);
    });

    // client.on('close', function (event) {
    //   console.error('mqtt close:', event);
    // });

    client.on('offline', function () {
      app.ports.mqttOnOffline.send(connectionAttempts.toString());
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
  } catch (e) {
    console.error('MQTT connection error', e);
  }
});

global.edice = app;
