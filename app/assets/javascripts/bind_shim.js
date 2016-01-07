//This is required for the wkhtmltopdf exporter to work correctly in production with compiled assets
Function.prototype.bind = Function.prototype.bind || function (thisp) {
  var fn = this;
  return function () {
    return fn.apply(thisp, arguments);
  };
};
