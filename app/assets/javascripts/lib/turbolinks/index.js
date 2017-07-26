import Turbolinks from 'turbolinks';
import morphdom from 'morphdom';
import delegate from 'delegate';

import serialize from 'form-serialize';

import {post} from 'lib/turbolinks/requests';

Turbolinks.start();
Turbolinks.SnapshotRenderer.prototype.assignNewBody = function () {
  morphdom(document.body,this.newBody,{});
};

document.addEventListener('submit', e => {
  let form = e.target;
  if (form.getAttribute('data-turbolinks-disable')) return;
  e.preventDefault();
  if (form.method === 'post') {
    post(form.action, new FormData(form));
  } else if (form.method === 'get') {
    Turbolinks.visit(`${form.action}?${serialize(form)}`);
  }
});

// Monkey patch for section ordinals
Turbolinks.Location.prototype.isHTML = function () {
  let extension = this.getExtension();
  return extension == null || extension == '' || extension.match(/^\.\d/);
};

// Monkey patch for scroll persistence
Turbolinks.scroll = {};

Turbolinks.keepScrollPosition = function () {
  Turbolinks.scroll['top'] = document.body.scrollTop;
};

delegate(document, '[data-turbolinks-scroll=false]', 'click', e => {
  Turbolinks.keepScrollPosition();
});

document.addEventListener('turbolinks:render', () => {
  if (Turbolinks.scroll['top']) {
    document.body.scrollTop =Turbolinks.scroll['top'];
  }
  Turbolinks.scroll = {};
});

// Monkey patch Turbolinks to render 403, 404 & 500 normally
// See https://github.com/turbolinks/turbolinks/issues/179
window.Turbolinks.HttpRequest.prototype.requestLoaded = function() {
  return this.endRequest(function() {
    var code = this.xhr.status;
    if (200 <= code && code < 300 ||
        code === 403 || code === 404 || code === 500) {
      this.delegate.requestCompletedWithResponse(
          this.xhr.responseText,
          this.xhr.getResponseHeader("Turbolinks-Location"));
    } else {
      this.failed = true;
      this.delegate.requestFailedWithStatusCode(code, this.xhr.responseText);
    }
  }.bind(this));
};
