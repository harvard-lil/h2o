import {html} from 'es6-string-html-template';
import {post, rest_delete} from 'lib/requests';
import throttle from 'lodash.throttle';
import Component from 'lib/ui/component'
import delegate from 'delegate';

delegate(document, '.annotate.elide', 'click', e => {
  let annotationId = e.target.dataset.annotationId;
  let elisions = document.querySelectorAll(`.annotate.elided[data-annotation-id="${annotationId}"]`);

  e.target.classList.toggle('revealed')
  for (let el of elisions) {
    el.classList.toggle('revealed');
  }
});
