var keys = [
  "kick",
  "start",
  "finish",
  "turn",
  "diceroll",
  "rollSuccess",
  "rollDefeat",
];

var sounds = {};

setTimeout(function() {
  window.AudioContext = window.AudioContext || window.webkitAudioContext;
  keys.forEach(function(key) {
    var url = "sounds/" + key + ".ogg";
    fetch(url)
      .then(function(response) {
        return response.arrayBuffer();
      })
      .then(function(arrayBuffer) {
        sounds[key] = function() {
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
        };
      });
  });
}, 1);

module.exports.play = function(sound) {
  if (!sounds[sound]) {
    console.error("sound not loaded:", sound);
    return;
  }
  sounds[sound]();
};
