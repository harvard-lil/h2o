import delegate from 'delegate';
import {stageChangeToAnnotation, isEditable, editAnnotationHandle, setFocus, stagePreviousContent} from 'lib/ui/content/annotations';

delegate(document, '.annotate.note', 'click', e => {
  let annotationId = e.target.dataset.annotationId;

  document.querySelector(`.annotate.note-content-wrapper[data-annotation-id="${annotationId}"]`)
  .classList.toggle('revealed');
});

// Stage content for cancel to work and override the default select action which would keep the `create-menu` open
delegate(document, '.note-content', 'click', e => {
  handleNoteContentPressed(e)
});

delegate(document, '.note-icon', 'click', e => {
  let annotationId = e.delegateTarget.dataset.annotationId;
  
  document.querySelector(`.annotate.note-content-wrapper[data-annotation-id="${annotationId}"]`)
  .classList.toggle('revealed');
});

delegate(document, '.note-content', 'input', e => {
  stageChangeToAnnotation(e.target.parentElement.previousElementSibling, {content: e.target.innerText});
});

function handleNoteContentPressed(e){
  if (isEditable()) {
    editAnnotationHandle(e.target.parentElement.previousElementSibling);
    stagePreviousContent(e.target.innerText);
    setFocus(e.target);
  }
}
