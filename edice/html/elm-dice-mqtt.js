var mqtt = require("paho-mqtt");

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
  } else if (self.location.hostname === "localhost") {
    // e2e tests and screenshots
    return {
      protocol: "ws",
      hostname: self.location.hostname,
      port: 80,
      path: "mqtt",
      username: "elm",
      password: jwt,
    };
  } else if (self.location.hostname === "nginx") {
    // e2e tests and screenshots
    return {
      protocol: "ws",
      path: "mqtt",
      username: "elm",
      password: jwt,
      hostname: "emqx",
      port: 8083,
    };
  } else {
    return {
      protocol: "wss",
      path: "mqtt",
      hostname: "qdice.wtf",
      port: 443,
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
  client = new mqtt.Client(mqttConfig.hostname, mqttConfig.port, "/" + mqttConfig.path, clientId);
  var willMessage = new mqtt.Message(clientId);
  willMessage.destinationName = "death";
  client.connect({
    uris: [url],
    userName: mqttConfig.username,
    password: mqttConfig.password,
    willMessage: willMessage,
    onSuccess: function() {
      postMessage({ type: "mqttOnConnected", payload: clientId });
      connectionAttempts = 0;
    },
    onFailure: function(_, error, message) {
      console.error("connection error", error, message);
    }
  });

  var connectionAttempts = 0;

  postMessage({ type: "mqttOnConnect", payload: "" });

  client.onMessageArrived = function(message) {
    postMessage({
      type: "mqttOnMessage",
      payload: [message.destinationName, message.payloadString],
    });
  };

  client.onConnectionLost = function(code, message) {
    console.error("mqtt connection lost:", code, message);
    postMessage({
      type: "mqttOnOffline",
      payload: connectionAttempts.toString(),
    });
  };

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
  client.subscribe(payload, {
    onSuccess: function() {
      postMessage({ type: "mqttOnSubscribed", payload: payload });
    }
  });
};

module.exports.unsubscribe = function(payload) {
  client.unsubscribe(payload);
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
