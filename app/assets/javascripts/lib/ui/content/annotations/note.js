import delegate from 'delegate';

delegate(document, '.annotate.note', 'click', e => {
  let annotationId = e.target.dataset.annotationId;

  document.querySelector(`.annotate.note-content-wrapper[data-annotation-id="${annotationId}"]`)
  .classList.toggle('revealed');
});


delegate(document, '.note-icon', 'click', e => {
  let annotationId = e.delegateTarget.dataset.annotationId;
  
  document.querySelector(`.annotate.note-content-wrapper[data-annotation-id="${annotationId}"]`)
  .classList.toggle('revealed');
});