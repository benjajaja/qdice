console.log('elm-dice-webworker reporting in');
var mqtt = require('mqtt');

var mqttConfig = {
  protocol: 'wss',
  hostname: 'm21.cloudmqtt.com',
  port: 31201,
  path: 'mqtt',
  username: 'web',
  password: 'web',
}

var client;
self.addEventListener('message', function(event){
  var action = event.data;
  switch (action.type) {
    case 'connect':
      var url = [ mqttConfig.protocol, 
        '://', 
        mqttConfig.hostname,
        ':',
        mqttConfig.port,
        '/',
        mqttConfig.path,
      ].join('');
      var clientId = 'elm-dice_' + Math.random().toString(16).substr(2, 8);
      self.document = {URL: action.url};
      client = mqtt.connect(url, {
        clientId: clientId,
        username: mqttConfig.username,
        password: mqttConfig.password,
      });

      var connectionAttempts = 0;

      postMessage({ type: 'mqttOnConnect', payload: ''});

      client.on('connect', function (connack) {
        postMessage({ type: 'mqttOnConnected', payload: clientId});
        connectionAttempts = 0;
      });

      client.on('message', function (topic, message) {
        postMessage({ type: 'mqttOnMessage', payload: [topic, message.toString()]});
      });

      client.on('error', function (error) {
        console.error('mqtt error:', error);
      });

      client.on('reconnect', function () {
        connectionAttempts = connectionAttempts + 1;
        postMessage({ type: 'mqttOnReconnect', payload: connectionAttempts});
      });

       client.on('close', function (event) {
         console.error('mqtt close:', event);
       });

      client.on('offline', function () {
        postMessage({ type: 'mqttOnOffline', payload: connectionAttempts.toString()});
      });
      break;
    case 'subscribe':
      client.subscribe(action.payload, function(err, granted) {
        if (err) throw err;
        postMessage({ type: 'mqttOnSubscribed', payload: granted.shift().topic});
      });
      break;
    case 'unsubscribe':
      client.unsubscribe(action.payload, function(err, granted) {
        if (err) throw err;
        //postMessage({ type: 'mqttOnSubscribed', payload: granted.shift().topic});
      });
      break;
    case 'publish':
      client.publish(action.payload[0], action.payload[1]);
      break;
  }
});  

var postMessage = function(message) {
  if (self.clients) {
    self.clients.matchAll().then(function(clients) {
      clients.forEach(function(client) {
        client.postMessage(message);
      });
    });
  } else {
    self.postMessage(message);
  }
};

