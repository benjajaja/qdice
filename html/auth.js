module.exports = function(callback) {

  //if (window.location.hash.indexOf('#access_token=') !== 0) {
    //var token = localStorage.getItem('id_token');
    //if (token) {
      //var profile = JSON.parse(localStorage.getItem('profile'));
      //setTimeout(callback.bind(null, token, profile));
    //}
  //}
  return function(strings) {
    if (strings.length === 1) {
      localStorage.setItem('id_token', strings[0]);
    } else if (strings.length === 3) {
      var profile = { email: strings[0], name: strings[1], picture: strings[2] };
      localStorage.setItem('profile', JSON.stringify(profile));
    } else {
      throw Error('could not persist session');
    }
  };
}
