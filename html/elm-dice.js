'use strict';

window.onerror = function(messageOrEvent, source, lineno, colno, error) {
  var element = document.createElement('div');
  element.innerHTML = messageOrEvent.toString();
  element.className = 'GLOBAL_ERROR';
  document.body.append(element);
  return false; // let built in handler log it too
};

if (window.navigator.standalone === true) {
  var fragment = document.createElement('div');
  fragment.style.height = '10px';
  fragment.style.background = '#2196f3';
  document.body.insertBefore(fragment, document.body.childNodes[0]);
  // mobile app
  document.body.classList.add('navigator-standalone');
  document.addEventListener('contextmenu', function (event) { event.preventDefault(); });
  var viewportmeta = document.querySelector('meta[name="viewport"]');
  viewportmeta.content = 'user-scalable=NO, width=device-width, initial-scale=1.0'
}

var Elm = require('../src/App');

var app = Elm.Edice.fullscreen();

app.ports.hide.subscribe(function(msg) {
  document.getElementById('loading-indicator').remove();
  window.onerror = function(messageOrEvent, source, lineno, colno, error) {
    window.alert(messageOrEvent.toString());
    return false; // let built in handler log it too
  };
});


if (window.location.hash.indexOf('#access_token=') !== 0) {
  var token = localStorage.getItem('jwt_token');
  if (token) {
    setTimeout(app.ports.onToken.send.bind(app.ports.onToken, token));
  }
}
app.ports.auth.subscribe(function(args) {
  if (args.length === 1) {
    localStorage.setItem('jwt_token', args);
  } else {
    localStorage.removeItem('jwt_token');
  }
});

app.ports.selectAll.subscribe(function(id) {
  var selection = window.getSelection();
  var range = document.createRange();
  range.selectNodeContents(document.getElementById(id));
  selection.removeAllRanges();
  selection.addRange(range);
});

app.ports.consoleDebug.subscribe(function(string) {
  var lines = string.split('\n');
  console.groupCollapsed(lines.shift());
  console.debug(lines.join('\n'));
  console.groupEnd();
});

const sounds = {};
setTimeout(() => {
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
            alert('error decoding file data: ' + url);
            return;
          }
          loader.bufferList[index] = buffer;
          if (++loader.loadCount == loader.urlList.length) {
            console.log('loaded all buffers');
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
  const keys = [ 'kick', 'diceroll', 'rollSuccess', 'rollDefeat' ];
  window.AudioContext = window.AudioContext || window.webkitAudioContext;
  const context = new AudioContext();
  const bufferLoader = new BufferLoader(
    context,
    keys.map(function(key) {
      return 'sounds/' + key + '.wav';
    }),
    function finishedLoading(bufferList) {
      console.log(bufferList);
      keys.forEach(function(key, index) {
        sounds[key] = function() {
          const source = context.createBufferSource();
          source.buffer = bufferList[index];
          source.connect(context.destination);
          console.log('play buffer', key);
          source.start(0);
        };
      });
    }
  );

  bufferLoader.load();
}, 1);
app.ports.playSound.subscribe(function(sound) {
	sounds[sound]();
});


app.ports.mqttConnect.subscribe(function() {
  var Worker = require('worker-loader!./elm-dice-webworker.js');
  var worker = new Worker();
  worker.postMessage({type: 'connect', url: location.href});
  worker.addEventListener('message', function(event) {
    var action = event.data;
    app.ports[action.type].send(action.payload);
  });
  app.ports.mqttSubscribe.subscribe(function(args) {
    worker.postMessage({type: 'subscribe', payload: args});
  })
  app.ports.mqttPublish.subscribe(function(args) {
    worker.postMessage({type: 'publish', payload: args});
  })
});

app.ports.scrollChat.subscribe(function(id) {
  var element = document.getElementById(id);
  if (!element) return console.error('cannot scroll #' + id);
  var height = element.clientHeight;
  var scroll = element.scrollTop;
  var innerHeight = element.scrollHeight;
  if (innerHeight - scroll === height) {
    setTimeout(function() {
      element.scrollTop = innerHeight;
    }, 100);
  }
});

global.edice = app;

if ('serviceWorker' in navigator) {
  window.addEventListener('load', function() {
    navigator.serviceWorker.register('/elm-dice-serviceworker.js').then(function(reg) {
      console.log('◕‿◕', reg);
    }, function(err) {
      console.log('ಠ_ಠ', err);
    });
  });
}

