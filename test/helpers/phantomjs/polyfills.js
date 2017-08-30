window.disableTurbolinks = true;

document.addEventListener('turbolinks:before-visit', function (e) {
  e.preventDefault();
  location.href = event.data.url;
});


if (!String.prototype.startsWith) {
    String.prototype.startsWith = function(searchString, position){
      position = position || 0;
      return this.substr(position, searchString.length) === searchString;
  };
}
