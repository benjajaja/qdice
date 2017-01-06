'use strict';

window.onerror = function(messageOrEvent, source, lineno, colno, error) {
  var element = document.createElement('div');
  element.innerHTML = messageOrEvent.toString();
  document.body.append(element);
  return false; // let built in handler log it too
};


var Auth0Lock = require('auth0-lock')['default'];

var lock = new Auth0Lock('vxpcYiPeQ6A2CgYG1QiUwLjQiU9JLPvj', 'easyrider.eu.auth0.com', {
  allowSignUp: false,
  allowedConnections: ['google-oauth2', 'github', 'bitbucket', 'twitter', 'facebook'],
  auth: {
    redirectUrl: [location.protocol, '//', location.hostname].join('')
      + (location.port && location.port != '80' ? ':' + location.port : '')
  },
  theme: {
    displayName: 'Login',
    logo: 'favicons/android-chrome-72x72.png'
  }
});

global.login = function() {
  lock.show();
};

lock.on("authenticated", function(authResult) {
  lock.getProfile(authResult.idToken, function(error, profile) {
    if (error) {
      console.error(error);
      return;
    }
    localStorage.setItem('id_token', authResult.idToken);
    // Display user information
    console.log(profile);
    app.ports.onLogin.send([profile.email, profile.name, profile.picture]);
  });
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

