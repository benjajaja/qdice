module.exports = function(callback) {

  if (window.location.hash.indexOf('#access_token=') !== 0) {
    var token = localStorage.getItem('jwt_token');
    if (token) {
      setTimeout(callback.bind(null, token));
    }
  }
  return function(strings) {
    if (strings.length === 1) {
      localStorage.setItem('jwt_token', strings[0]);
    }
  };
}
