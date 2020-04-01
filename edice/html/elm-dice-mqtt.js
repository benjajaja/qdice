var mqtt = require("mqtt");

function getMqttConfig(jwt) {
  if (
    (self.location.hostname === "localhost" && self.location.port === "5000") ||
    self.location.hostname === "lvh.me"
  ) {
    // local env
    return {
      protocol: "ws",
      hostname: self.location.hostname,
      port: 8083,
      path: "mqtt",
      username: "elm",
      password: jwt,
    };
  } else if (
    self.location.hostname === "nginx" ||
    self.location.hostname === "localhost"
  ) {
    // e2e tests
    return {
      protocol: "ws",
      path: "mqtt",
      username: "elm",
      password: jwt,
    };
  } else {
    return {
      protocol: "wss",
      path: "mqtt",
      hostname: "qdice.wtf",
      username: "elm",
      password: jwt,
    };
  }
}

var client;

module.exports.connect = function(jwt) {
  var mqttConfig = getMqttConfig(jwt);
  var url = [mqttConfig.protocol, "://", mqttConfig.hostname]
    .concat(mqttConfig.port ? [":", mqttConfig.port] : [])
    .concat(["/", mqttConfig.path])
    .join("");
  var clientId = sessionClientId();
  client = mqtt.connect(url, {
    clientId: clientId,
    username: mqttConfig.username,
    password: mqttConfig.password,
    resubscribe: false,
    will: {
      topic: "death",
      payload: clientId,
      properties: {
        willDelayInterval: 1,
      },
    },
  });

  var connectionAttempts = 0;

  postMessage({ type: "mqttOnConnect", payload: "" });

  client.on("connect", function(connack) {
    postMessage({ type: "mqttOnConnected", payload: clientId });
    connectionAttempts = 0;
  });

  client.on("message", function(topic, message) {
    postMessage({
      type: "mqttOnMessage",
      payload: [topic, message.toString()],
    });
  });

  client.on("error", function(error) {
    console.error("mqtt error:", error);
  });

  client.on("reconnect", function() {
    connectionAttempts = connectionAttempts + 1;
    postMessage({ type: "mqttOnReconnect", payload: connectionAttempts });
  });

  client.on("close", function(event) {
    console.error("mqtt close:", event);
    postMessage({
      type: "mqttOnOffline",
      payload: connectionAttempts.toString(),
    });
  });

  client.on("offline", function() {
    postMessage({
      type: "mqttOnOffline",
      payload: connectionAttempts.toString(),
    });
  });

  window.mqttClient = client; // for e2e
};

var postMessage = function(message) {
  if (module.exports.onmessage) {
    module.exports.onmessage(message);
  } else {
    console.error("mqtt postMessage not set");
  }
};

module.exports.subscribe = function(payload) {
  client.subscribe(payload, function(err, granted) {
    if (err) {
      postMessage({ type: "mqttOnError", payload: err.toString() });
    } else {
      granted.forEach(function(granted) {
        postMessage({ type: "mqttOnSubscribed", payload: granted.topic });
      });
    }
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

function sessionClientId() {
  try {
    var existing = window.sessionStorage.getItem("clientId");
    if (typeof existing === "string" && existing.length === 17) {
      return existing;
    }
    var id = generateSessionClientId();
    window.sessionStorage.setItem("clientId", id);
    return id;
  } catch (e) {
    return generateSessionClientId();
  }
}

function generateSessionClientId() {
  return (
    "elm-dice_" +
    Math.random()
      .toString(16)
      .substr(2, 8)
  );
}
