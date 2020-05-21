var keys = [
  "kick",
  "start",
  "finish",
  "turn",
  "diceroll",
  "rollSuccess",
  "rollSuccessPlayer",
  "rollDefeat",
  "giveDice",
];

var sounds = {};

setTimeout(function() {
  try {
    window.AudioContext = window.AudioContext || window.webkitAudioContext;
    keys.forEach(function(key) {
      sounds[key] = function() {
        var url = "sounds/" + key + ".ogg";
        fetch(url)
          .then(function(response) {
            return response.arrayBuffer();
          })
          .then(function(arrayBuffer) {
            var context = new AudioContext();
            context.decodeAudioData(
              arrayBuffer,
              function(buffer) {
                if (!buffer) {
                  console.error("error decoding file data: " + url);
                  return;
                }
                sounds[key] = function() {
                  var source = context.createBufferSource();
                  source.buffer = buffer;
                  source.connect(context.destination);
                  source.start(0);
                };
                sounds[key]();
              },
              function(error) {
                console.error("decodeAudioData error", error);
              }
            );
          })
          .catch(function(error) {
            var Sentry = require("@sentry/browser");
            Sentry.captureException(error);
          });
      };
    });
  } catch (e) {
    var Sentry = require("@sentry/browser");
    Sentry.captureException(e);
  }
}, 1);

module.exports.play = function(sound) {
  if (!sounds[sound]) {
    console.error("sound not loaded:", sound);
    return;
  }
  sounds[sound]();
};
