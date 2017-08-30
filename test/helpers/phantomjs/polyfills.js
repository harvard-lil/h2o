window.disableTurbolinks = true;

document.addEventListener('turbolinks:before-visit', function (e) {
  e.preventDefault();
  location.href = event.data.url;
});

window._test_window_urls = []
window._open = window.open;
window.open = function (path) {
  if (path[0] === '/') { path = location.origin + path; }
  window._test_window_urls.push(path);
  window._open.apply(window, arguments);
}

if (!String.prototype.startsWith) {
    String.prototype.startsWith = function(searchString, position){
      position = position || 0;
      return this.substr(position, searchString.length) === searchString;
  };
}
