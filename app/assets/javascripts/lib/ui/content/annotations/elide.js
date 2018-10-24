import {html} from 'es6-string-html-template';
import {post, rest_delete} from 'lib/requests';
import throttle from 'lodash.throttle';
import Component from 'lib/ui/component';
import delegate from 'delegate';

function handleElideButtonPressed(e){
  let annotationId = e.target.dataset.annotationId;
  let elisions = document.querySelectorAll(`.annotate.elided[data-annotation-id="${annotationId}"]`);
  toggleElisionVisibility(annotationId, 'elide', e.target, elisions);
}

function toggleAllElisions(e){
  // get all elisions & replacement annotations on page
  let elisions = document.querySelectorAll('.annotate.elide, .annotate.replacement');

  // loop through and toggle selected annotations
  elisions.forEach(function(elision){
    let annotationId = elision["dataset"]["annotationId"];

    if (elision.classList.contains('replacement')){
      let contentNodes = document.querySelectorAll(`.annotate.replaced[data-annotation-id="${annotationId}"]`);
      let button = document.querySelector(`.annotate.replacement[data-annotation-id="${annotationId}"]`);
      toggleElisionVisibility(annotationId, 'replace', button, contentNodes);
    } else {
      let contentNodes = document.querySelectorAll(`.annotate.elided[data-annotation-id="${annotationId}"]`);
      toggleElisionVisibility(annotationId, 'elide', elision, contentNodes);
    }
  });

  // change show all elisions toggle button text to reflect state
  let toggleElisionsButton = document.querySelector('.toggle-elisions');
  if (toggleElisionsButton.innerText === "Show elided text"){
    toggleElisionsButton.innerText = "Hide elided text";
  } else {
    toggleElisionsButton.innerText = "Show elided text";
  }
}

export function delegateElisionEvents(){
  // Respond to click, spacebar, or enter, like a real html button would
  delegate(document, '.annotate.elide', 'click', e => handleElideButtonPressed(e));
  delegate(document, '.annotate.elide', 'keypress', e => {
    if (e.key=='Enter'||e.key==' '||e.keyCode==13||e.keyCode==32){
      e.preventDefault();
      handleElideButtonPressed(e);
    }
  });

  delegate(document, '.toggle-elisions', 'click', e => toggleAllElisions(e));
}

export function toggleElisionVisibility(annotationId, annotationType, toggleButton, toggledContentNodes){
  toggleButton.classList.toggle('revealed');
  if (toggleButton.classList.contains('revealed')){
    toggleButton.setAttribute('aria-expanded', 'true');
    toggledContentNodes[toggledContentNodes.length - 1].insertAdjacentHTML('afterend', `<span class="annotate ${annotationType}d revealed sr-only" data-annotation-id="${annotationId}">(end of ${annotationType}d text)</span>`);
    for (let el of toggledContentNodes) {
      el.classList.add('revealed');
      try {
        // attempt to toggle on any enclosing wrappers, like blockquote tags
        el.parentElement.classList.add('revealed');
        // attempt to toggle off paragraph numbers
        el.parentElement.previousElementSibling.classList.add('revealed');
      } catch (e) {} // swallow the error if el has no wrapping parent or if el isn't preceded by paragraph number
    }
  } else {
    toggleButton.setAttribute('aria-expanded', 'false');
    toggledContentNodes[toggledContentNodes.length - 1].remove();
    for (let el of toggledContentNodes) {
      el.classList.remove('revealed');
      try {
        // attempt to toggle on any enclosing wrappers, like blockquote tags
        el.parentElement.classList.remove('revealed');
        // attempt to toggle off paragraph numbers
        el.parentElement.previousElementSibling.classList.remove('revealed');
      } catch (e) {} // swallow the error if el has no wrapping parent or if el isn't preceded by paragraph number
    }
  }
}
