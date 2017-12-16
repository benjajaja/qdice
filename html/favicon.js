module.exports = function(icon) {
  var path = 'favicons/favicon' + (icon ? '-' + icon : '') + '.png';
  var link = Array.prototype.slice.call(document.querySelectorAll('link[rel="icon"]')).pop();
  link.href = path;
};
