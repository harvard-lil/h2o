import {html} from 'es6-string-html-template';
import {post, rest_delete} from 'lib/turbolinks/requests';
import throttle from 'lodash.throttle';
import Component from 'lib/ui/component'
import delegate from 'delegate';
import debounce from 'debounce';
import {editAnnotationHandle, updateAnnotation} from 'lib/ui/content/annotations';

delegate(document, '.annotate.replacement', 'click', e => {
  editAnnotationHandle(e.target.previousElementSibling);
});

delegate(document, '.annotate.replacement', 'input', debounce(e => {
  updateAnnotation(e.target.previousElementSibling, {content: e.target.innerText});
}, 1000));

document.addEventListener('click', e => {
  console.log(e.target);
});
