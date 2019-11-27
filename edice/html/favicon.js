module.exports = function(icon) {
  var path = "favicons-2/favicon" + (icon ? "-" + icon : "") + ".png";

  Array.prototype.slice
    .call(
      document.querySelectorAll('link[rel="icon"],link[rel="shortcut icon"]')
    )
    .forEach(function(oldLink) {
      document.head.removeChild(oldLink);
    });

  var link = document.createElement("link");
  link.rel = "shortcut icon";
  link.href = path;
  document.head.appendChild(link);
};
