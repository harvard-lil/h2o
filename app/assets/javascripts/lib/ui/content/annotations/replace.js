import {html} from 'es6-string-html-template';
import {post, rest_delete} from 'lib/requests';
import throttle from 'lodash.throttle';
import Component from 'lib/ui/component'
import delegate from 'delegate';
import debounce from 'debounce';
import {editAnnotationHandle, stageChangeToAnnotation, stagePreviousContent, isEditable} from 'lib/ui/content/annotations';


// Respond to click, spacebar, or enter, like a real html button would
delegate(document, '.annotate.replacement', 'click', e => handleReplaceButtonPressed(e));
delegate(document, '.annotate.replacement', 'keypress', e => {
  if (e.key=='Enter'||e.key==' '||e.keyCode==13||e.keyCode==32){
    handleReplaceButtonPressed(e);
  }
});

// Pressing enter or spacebar in the contenteditable region shouldn't press the containing button
delegate(document, '.annotate.replacement .text', 'keypress', e => {
  if (e.key=='Enter'||e.key==' '||e.keyCode==13||e.keyCode==32){
    e.stopPropagation();
  }
}, true);

delegate(document, '.annotate.replacement .text', 'input', e => {
  stageChangeToAnnotation(e.target.parentElement.previousElementSibling, {content: e.target.innerText});
});

function handleReplaceButtonPressed(e){
  if (isEditable()) {
    editAnnotationHandle(e.target.previousElementSibling);
    stagePreviousContent(e.target.innerText);
    setFocus(e.target.firstElementChild);
  }
  if (!isEditable() || e.target.classList.contains('revealed')) {
    let annotationId = e.target.dataset.annotationId;
    let elisions = document.querySelectorAll(`.annotate.replaced[data-annotation-id="${annotationId}"]`);

    e.target.classList.toggle('revealed')
    for (let el of elisions) {
      el.classList.toggle('revealed');
    }
  }
}

function setFocus(el) {
    if (document.activeElement === el) { return; }
    var range = document.createRange();
    var sel = window.getSelection();
    range.setStart(el, 0);
    range.collapse(true);
    sel.removeAllRanges();
    sel.addRange(range);
    el.focus();
}
