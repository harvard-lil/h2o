import {html} from 'es6-string-html-template';
import {post, rest_delete} from 'lib/turbolinks/requests';
import throttle from 'lodash.throttle';
import Component from 'lib/ui/component'
import delegate from 'delegate';
import debounce from 'debounce';
import {editAnnotationHandle, updateAnnotation, isEditable} from 'lib/ui/content/annotations';

delegate(document, '.annotate.replacement', 'click', e => {
  if (isEditable()) {
    editAnnotationHandle(e.target.previousElementSibling);
  } else {
    let annotationId = e.target.dataset.annotationId;
    let elisions = document.querySelectorAll(`.annotate.replaced[data-annotation-id="${annotationId}"]`);

    e.target.classList.toggle('revealed')
    for (let el of elisions) {
      el.classList.toggle('revealed');
    }
  }
});

delegate(document, '.annotate.replacement', 'input', debounce(e => {
  updateAnnotation(e.target.previousElementSibling, {content: e.target.innerText});
}, 1000));

document.addEventListener('click', e => {
  console.log(e.target);
});
