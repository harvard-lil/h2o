//This helps prevent masking JavaScript error messages as wkhtmltopdf reports them
Function.prototype.bind = Function.prototype.bind || function (thisp) {
  var fn = this;
  return function () {
    return fn.apply(thisp, arguments);
  };
};
