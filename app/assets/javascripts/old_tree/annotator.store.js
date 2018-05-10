/*
** Annotator v2.0.0-dev.2-e021ea8
** https://github.com/okfn/annotator/
**
** Copyright 2014, the Annotator project contributors.
** Dual licensed under the MIT and GPLv3 licenses.
** https://github.com/okfn/annotator/blob/master/LICENSE
**
** Built at: 2014-04-29 20:06:43Z
*/
!function(e){if("object"==typeof exports)module.exports=e();else if("function"==typeof define&&define.amd)define(e);else{var n;"undefined"!=typeof window?n=window:"undefined"!=typeof global?n=global:"undefined"!=typeof self&&(n=self);var o=n;o=o.Annotator||(o.Annotator={}),o=o.Plugin||(o.Plugin={}),o.Store=e()}}(function(){var define,module,exports;return (function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);throw new Error("Cannot find module '"+o+"'")}var f=n[o]={exports:{}};t[o][0].call(f.exports,function(e){var n=t[o][1][e];return s(n?n:e)},f,f.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({"apYPS1":[function(_dereq_,module,exports){
(function (global){
var Annotator, self, _ref;

if (typeof self !== "undefined" && self !== null) {
  self = self;
}

if (typeof global !== "undefined" && global !== null) {
  if (self == null) {
    self = global;
  }
}

if (typeof window !== "undefined" && window !== null) {
  if (self == null) {
    self = window;
  }
}

Annotator = self != null ? self.Annotator : void 0;

if (Annotator == null) {
  Annotator = (self != null ? (_ref = self.define) != null ? _ref.amd : void 0 : void 0) ? self != null ? self.require('annotator') : void 0 : void 0;
}

if (typeof Annotator !== 'function') {
  throw new Error("Could not find Annotator! In a webpage context, please ensure that the Annotator script tag is loaded before any plugins.");
}

module.exports = Annotator;


}).call(this,typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {})
},{}],"annotator":[function(_dereq_,module,exports){
module.exports=_dereq_('apYPS1');
},{}],3:[function(_dereq_,module,exports){
var $, Annotator, Store, Util, _t;

Annotator = _dereq_('annotator');

Util = Annotator.Util;

$ = Util.$;

_t = Util.TranslationString;

Store = (function() {
  Store.prototype.options = {
    annotationData: null,
    emulateHTTP: false,
    emulateJSON: false,
    headers: {},
    prefix: '/store',
    urls: {
      create: '/annotations',
      read: '/annotations/:id',
      update: '/annotations/:id',
      destroy: '/annotations/:id',
      search: '/search'
    }
  };

  function Store(options) {
    if (arguments.length > 1) {
      options = arguments[1];
    }
    this.options = $.extend(true, {}, this.options, options);
    if (this.options.loadFromSearch) {
      Util.deprecationWarning("Use of the loadFromSearch option to the Store plugin is deprecated. Please call .load(queryObj) on the Annotator instance instead.");
    }
  }

  Store.prototype.pluginInit = function() {
    this.annotator.store = this;
    if (this.options.loadFromSearch) {
      return this.annotator.load(this.options.loadFromSearch);
    }
  };

  Store.prototype.create = function(annotation) {
    return this._apiRequest('create', annotation);
  };

  Store.prototype.update = function(annotation) {
    return this._apiRequest('update', annotation);
  };

  Store.prototype["delete"] = function(annotation) {
    return this._apiRequest('destroy', annotation);
  };

  Store.prototype.query = function(queryObj) {
    var dfd;
    dfd = $.Deferred();
    this._apiRequest('search', queryObj).done(function(obj) {
      var rows;
      rows = obj.rows;
      delete obj.rows;
      return dfd.resolve(rows, obj);
    }).fail(function() {
      return dfd.reject.apply(dfd, arguments);
    });
    return dfd.promise();
  };

  Store.prototype.setHeader = function(key, value) {
    return this.options.headers[key] = value;
  };

  Store.prototype._apiRequest = function(action, obj) {
    var id, options, request, url;
    id = obj && obj.id;
    url = this._urlFor(action, id);
    options = this._apiRequestOptions(action, obj);
    request = $.ajax(url, options);
    request._id = id;
    request._action = action;
    return request;
  };

  Store.prototype._apiRequestOptions = function(action, obj) {
    var data, method, opts;
    method = this._methodFor(action);
    opts = {
      type: method,
      dataType: "json",
      error: this._onError,
      headers: this.options.headers
    };
    if (this.options.emulateHTTP && (method === 'PUT' || method === 'DELETE')) {
      opts.headers = $.extend(opts.headers, {
        'X-HTTP-Method-Override': method
      });
      opts.type = 'POST';
    }
    if (action === "search") {
      opts = $.extend(opts, {
        data: obj
      });
      return opts;
    }
    if (this.options.annotationData != null) {
      Util.deprecationWarning("Use of the annotationData option to the Store plugin is deprecated and will be removed in a future version. Please use hooks to beforeAnnotationCreated and beforeAnnotationUpdated to replicate this behaviour.");
      $.extend(obj, this.options.annotationData);
    }
    data = obj && JSON.stringify(obj);
    if (this.options.emulateJSON) {
      opts.data = {
        json: data
      };
      if (this.options.emulateHTTP) {
        opts.data._method = method;
      }
      return opts;
    }
    opts = $.extend(opts, {
      data: data,
      contentType: "application/json; charset=utf-8"
    });
    return opts;
  };

  Store.prototype._urlFor = function(action, id) {
    var url;
    url = this.options.prefix != null ? this.options.prefix : '';
    url += this.options.urls[action];
    url = url.replace(/\/:id/, id != null ? '/' + id : '');
    url = url.replace(/:id/, id != null ? id : '');
    return url;
  };

  Store.prototype._methodFor = function(action) {
    var table;
    table = {
      create: 'POST',
      read: 'GET',
      update: 'PUT',
      destroy: 'DELETE',
      search: 'GET'
    };
    return table[action];
  };

  Store.prototype._onError = function(xhr) {
    var action, message;
    action = xhr._action;
    message = _t("Sorry we could not ") + action + _t(" this annotation");
    if (xhr._action === 'search') {
      message = _t("Sorry we could not search the store for annotations");
    } else if (xhr._action === 'read' && !xhr._id) {
      message = _t("Sorry we could not ") + action + _t(" the annotations from the store");
    }
    switch (xhr.status) {
      case 401:
        message = _t("Sorry you are not allowed to ") + action + _t(" this annotation");
        break;
      case 404:
        message = _t("Sorry we could not connect to the annotations store");
        break;
      case 500:
        message = _t("Sorry something went wrong with the annotation store");
    }
    Annotator.showNotification(message, Annotator.Notification.ERROR);
    return console.error(_t("API request failed:") + (" '" + xhr.status + "'"));
  };

  return Store;

})();

Annotator.Plugin.register('Store', Store);

module.exports = Store;


},{}]},{},[3])

(3)
});

