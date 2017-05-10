import Turbolinks from 'turbolinks';
import morphdom from 'morphdom';

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
    post(form.action, {data: serialize(form)});
  } else if (form.method === 'get') {
    Turbolinks.visit(`${form.action}?${serialize(form)}`);
  }
});
