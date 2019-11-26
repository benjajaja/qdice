var mqtt = require('mqtt');

function getMqttConfig() {
  if (['localhost', 'lvh.me'].indexOf(self.location.hostname) !== -1) {
    return {
      protocol: 'ws',
      hostname: self.location.hostname,
      port: 8083,
      path: 'mqtt',
      username: 'client',
      password: 'client',
    };
  } else if (self.location.hostname === 'edice') {
    return {
      protocol: 'ws',
      path: 'mqtt',
    };
  } else {
    return {
      protocol: 'wss',
      path: 'mqtt',
    };
  }
}

var client;

module.exports.connect = function() {
  var mqttConfig = getMqttConfig();
  var url = [mqttConfig.protocol, '://', mqttConfig.hostname]
    .concat(mqttConfig.port ? [':', mqttConfig.port] : [])
    .concat(['/', mqttConfig.path])
    .join('');
  var clientId =
    'elm-dice_' +
    Math.random()
      .toString(16)
      .substr(2, 8);
  client = mqtt.connect(url, {
    clientId: clientId,
    username: mqttConfig.username,
    password: mqttConfig.password,
  });

  var connectionAttempts = 0;

  postMessage({type: 'mqttOnConnect', payload: ''});

  client.on('connect', function(connack) {
    postMessage({type: 'mqttOnConnected', payload: clientId});
    connectionAttempts = 0;
  });

  client.on('message', function(topic, message) {
    postMessage({type: 'mqttOnMessage', payload: [topic, message.toString()]});
  });

  client.on('error', function(error) {
    console.error('mqtt error:', error);
  });

  client.on('reconnect', function() {
    connectionAttempts = connectionAttempts + 1;
    postMessage({type: 'mqttOnReconnect', payload: connectionAttempts});
  });

  client.on('close', function(event) {
    console.error('mqtt close:', event);
  });

  client.on('offline', function() {
    postMessage({
      type: 'mqttOnOffline',
      payload: connectionAttempts.toString(),
    });
  });

  window.mqttClient = client; // for e2e
};

var postMessage = function(message) {
  if (module.exports.onmessage) {
    module.exports.onmessage(message);
  } else {
    console.error('mqtt postMessage not set');
  }
};

module.exports.subscribe = function(payload) {
  client.subscribe(payload, function(err, granted) {
    if (err) throw err;
    postMessage({type: 'mqttOnSubscribed', payload: granted[0].topic});
    //console.log('sub', granted[0].topic);
  });
};

module.exports.unsubscribe = function(payload) {
  client.unsubscribe(payload, function(err, granted) {
    if (err) throw err;
    //postMessage({ type: 'mqttOnUnSubscribed', payload: granted.shift().topic});
  });
};

module.exports.publish = function(payload) {
  client.publish(payload[0], payload[1]);
};
