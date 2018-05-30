import {html} from 'es6-string-html-template';
import {post, rest_delete} from 'lib/requests';
import throttle from 'lodash.throttle';
import Component from 'lib/ui/component'
import delegate from 'delegate';

delegate(document, '.annotate.elide', 'click', e => {
  let annotationId = e.target.dataset.annotationId;
  let elisions = document.querySelectorAll(`.annotate.elided[data-annotation-id="${annotationId}"]`);

  e.target.classList.toggle('revealed');
  if (e.target.classList.contains('revealed')){
    e.target.setAttribute('aria-expanded', 'true');
    elisions[elisions.length - 1].insertAdjacentHTML('afterend', `<span class="annotate elided revealed sr-only" data-annotation-id="${annotationId}">(end of elided text)</span>`);
  } else {
    e.target.setAttribute('aria-expanded', 'false');
    elisions[elisions.length - 1].remove();
  }
  for (let el of elisions) {
    el.classList.toggle('revealed');
    el.parentElement.classList.toggle('revealed');
  }
});
