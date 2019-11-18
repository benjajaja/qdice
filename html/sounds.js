var keys = [
  'kick',
  'start',
  'finish',
  'turn',
  'diceroll',
  'rollSuccess',
  'rollDefeat',
];

var sounds = {};

setTimeout(function() {
  window.AudioContext = window.AudioContext || window.webkitAudioContext;
  keys.forEach(function(key) {
    var url = 'sounds/' + key + '.ogg';
    var request = new XMLHttpRequest();
    request.open('GET', url, true);
    request.responseType = 'arraybuffer';
    request.onload = function() {
      var response = request.response;

      sounds[key] = function() {
        var context = new AudioContext();
        context.decodeAudioData(
          response,
          function(buffer) {
            if (!buffer) {
              console.error('error decoding file data: ' + url);
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
            console.error('decodeAudioData error', error);
          }
        );
      };
    };
    request.onerror = function() {
      console.error('BufferLoader: XHR error');
    };
    request.send();
  });
}, 1);

module.exports.play = function(sound) {
  if (!sounds[sound]) {
    console.error('sound not loaded:', sound);
    return;
  }
  sounds[sound]();
};
