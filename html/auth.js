module.exports = function(callback) {
  var Auth0Lock = require('auth0-lock')['default'];

  var lock = new Auth0Lock('vxpcYiPeQ6A2CgYG1QiUwLjQiU9JLPvj', 'easyrider.eu.auth0.com', {
    allowSignUp: false,
    allowedConnections: ['google-oauth2', 'github', 'bitbucket', 'twitter', 'facebook'],
    auth: {
      responseType: 'token',
      sso: true,
      redirectUrl: [location.protocol, '//', location.hostname].join('')
        + (location.port && location.port != '80' ? ':' + location.port : '')
    },
    theme: {
      displayName: 'Login',
      logo: 'favicons/android-chrome-72x72.png'
    }
  });

  global.login = function() {
    var token = localStorage.getItem('id_token');
    if (token) {
      localStorage.removeItem('id_token');
      localStorage.removeItem('profile');
      window.location.reload();
    } else {
      lock.show();
    }
  };

  lock.on("authenticated", function(authResult) {
    lock.getProfile(authResult.idToken, function(error, profile) {
      if (error) {
        console.error(error);
        return;
      }
      localStorage.setItem('id_token', authResult.idToken);
      localStorage.setItem('profile', JSON.stringify(profile));
      // Display user information
      console.log(profile);
      callback(profile);
    });
  });

  var token = localStorage.getItem('id_token');
  if (token) {
    var profile = JSON.parse(localStorage.getItem('profile'));
    setTimeout(callback.bind(null, profile));
  }
};