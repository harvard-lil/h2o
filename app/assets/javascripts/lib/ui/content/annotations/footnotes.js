import delegate from 'delegate';
// if a footnote links to an elided or replaced segment, open it before jumping

delegate(document, '.case-text a', 'click', e => {
  if (e.target.hash && e.target.origin == location.origin && e.target.pathname == location.pathname) {
    // link is a footnote or back-ref
    let jumpTarget = document.querySelector(`.case-text a[name="${e.target.hash.slice(1)}"]`);
    let annotationContainer = jumpTarget.closest('.annotate[data-annotation-id]') || jumpTarget.querySelector('[data-annotation-id]');
    if (annotationContainer) { // jump target is possibly hidden (todo: test annotation type)
      let elisions = document.querySelectorAll(`.annotate[data-annotation-id="${annotationContainer.dataset.annotationId}"]`);
      for (let el of elisions) {
        el.classList.add('revealed');
      }
    }
  }
});
