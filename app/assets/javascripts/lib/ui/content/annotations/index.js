import {html} from 'es6-string-html-template';
import {post, patch, rest_delete} from 'lib/requests';
import throttle from 'lodash.throttle';
import Component from 'lib/ui/component';
import delegate from 'delegate';

import {Annotator} from 'lib/ui/content/annotations/annotator.js.erb';
import {getQueryStringDict} from 'lib/helpers';

import { delegateElisionEvents } from 'lib/ui/content/annotations/elide';
import 'lib/ui/content/annotations/replace';
import 'lib/ui/content/annotations/note';
import 'lib/ui/content/annotations/footnotes';
import 'lib/ui/content/annotations/placement';

let annotator = null;

delegateElisionEvents();

// Set focus to a particular replace on page load if specified in query string
window.addEventListener('load', () => {
  let query = getQueryStringDict();
  if (query['annotation-id']) {
    let annotation = document.querySelector(`.annotate[data-annotation-id="${query['annotation-id']}"]`);
    if (annotation){
      setFocus(annotation);
      annotation.scrollIntoView(true);
    };
  }
});

$('.view-resources-annotate').ready(e => {
  annotator = new Annotator();
  makeReplacementsContenteditable();
});

delegate(document, '.annotate.replacement', 'focus', e => {
  annotator.edit(e.target.previousElementSibling);
});

export function setFocus(el) {
    if (document.activeElement === el) { return; }
    var range = document.createRange();
    var sel = window.getSelection();
    range.setStart(el, 0);
    range.collapse(true);
    sel.removeAllRanges();
    sel.addRange(range);
    el.focus();
}

export function stageChangeToAnnotation(field, attrs) {
  if (!annotator) { return; }
  annotator.changeAnnotation(field, attrs);
}

export function stagePreviousContent(content) {
  if (!annotator) { return; }

  annotator.previousContent = content;
}

export function isEditable () {
  return document.querySelector('header.casebook').dataset.editable ? true : false;
}

function makeReplacementsContenteditable() {
  let replacements = document.querySelectorAll('.resource-wrapper .annotate.replacement .text');
  for (let el of replacements) { el.contentEditable = true; }
}

document.addEventListener('selectionchange', e => {
  if (!annotator ||
      e.target.activeElement.classList.contains("note") ||
      (annotator.handle && e.target.activeElement.dataset.annotationId == annotator.annotationId)) {
    return;
  }

  let selection = document.getSelection();

  let anchorElement = selection.anchorNode && selection.anchorNode.nodeType === document.TEXT_NODE ? selection.anchorNode.parentElement : selection.anchorNode;
  if (!anchorElement || anchorElement.closest('form.create-form')  || anchorElement.closest('#annotator')) { return; }

  if (selection.isCollapsed) {
    if (annotator.handle) {
      let parentSpan = selection.anchorNode.parentElement.closest('span');
      if (parentSpan && annotator.annotationId === parentSpan.dataset.annotationId) {
        return; // selected inside the current annotation, keep it focused
      }
      annotator.deactivate();
    } else {
      annotator.deactivate();
    }
  } else {
    let range = selection.getRangeAt(0);
    annotator.select(range);
  }
});

window.addEventListener('scroll', e => {
  if (annotator && annotator.active) {
    annotator.updateScroll();
  }
});
