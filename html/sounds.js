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
  function BufferLoader(context, urlList, callback) {
    this.context = context;
    this.urlList = urlList;
    this.onload = callback;
    this.bufferList = new Array();
    this.loadCount = 0;
  }

  BufferLoader.prototype.loadBuffer = function(url, index) {
    // Load buffer asynchronously
    var request = new XMLHttpRequest();
    request.open("GET", url, true);
    request.responseType = "arraybuffer";

    var loader = this;

    request.onload = function() {
      // Asynchronously decode the audio file data in request.response
      loader.context.decodeAudioData(
        request.response,
        function(buffer) {
          if (!buffer) {
            console.error('error decoding file data: ' + url);
            return;
          }
          loader.bufferList[index] = buffer;
          if (++loader.loadCount == loader.urlList.length) {
            loader.onload(loader.bufferList);
          }
        },
        function(error) {
          console.error('decodeAudioData error', error);
        }
      );
    }

    request.onerror = function() {
      console.error('BufferLoader: XHR error');
    }

    request.send();
  }

  BufferLoader.prototype.load = function() {
    for (var i = 0; i < this.urlList.length; ++i)
    this.loadBuffer(this.urlList[i], i);
  }
  window.AudioContext = window.AudioContext || window.webkitAudioContext;
  var context = new AudioContext();
  var bufferLoader = new BufferLoader(
    context,
    keys.map(function(key) {
      return 'sounds/' + key + '.ogg';
    }),
    function finishedLoading(bufferList) {
      keys.forEach(function(key, index) {
        sounds[key] = function() {
          var source = context.createBufferSource();
          source.buffer = bufferList[index];
          source.connect(context.destination);
          source.start(0);
        };
      });
    }
  );

  bufferLoader.load();
}, 1);

module.exports.play = function(sound) {
  if (!sounds[sound]) {
    console.error('sound not loaded:', sound);
    return;
  }
	sounds[sound]();
};

