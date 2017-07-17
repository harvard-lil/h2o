import {html, raw} from 'es6-string-html-template';
import {post, patch, rest_delete} from 'lib/turbolinks/requests';
import throttle from 'lodash.throttle';
import Component from 'lib/ui/component'
import delegate from 'delegate';

export class Annotator extends Component {
  constructor () {
    super({
      id: 'annotator',
      events: {
        'click .annotator-action': e => { this.doAnnotationAction(e); },
        'submit .create-form': e => { this.submitAnnotationForm(e); e.preventDefault(); }
      }
    });

    this.updateScroll = throttle(this.render, 100, {leading: true, trailing: true});

    document.querySelector('.resource-wrapper').appendChild(this.el);
    this.mode = 'inactive';
    this.render();
  }

  destroy () {
    super.destroy();
    this.updateScroll.cancel();
  }

  template () {
    let inner;
    switch (this.mode) {
    case 'inactive':
      inner = '';
    case 'create-menu':
      inner = this.menuTemplate();
      break;
    case 'edit-handle':
      inner = this.editTemplate();
      break;
    case 'new-form':
      inner = this.newTemplate();
      break;
    }
    return html`<div id="annotator" class="${this.mode == 'inactive' ? 'hide' : ''}" style="top: ${this.calcTopOffset().toString(10)}px">
      <div class="annotator-inner">
        ${raw(inner)}
      </div>
    </div>`;
  }

    editTemplate () {
      switch (this.handle.dataset.annotationType) {
      case 'highlight':
        return html`
          <a class="annotator-action" data-annotate-action="destroy">Remove highlight</a>
          <a class="annotator-action" data-annotate-action="convert" data-annotation-type="note">Add note</a>
        `;
      case 'elide':
        return html`
          <a class="annotator-action" data-annotate-action="destroy">Restore text</a>
          <a class="annotator-action" data-annotate-action="convert" data-annotation-type="replace">Replace text</a>
        `;
      case 'replace':
        return html`
          <a class="annotator-action" data-annotate-action="destroy">Restore text</a>
          <a class="annotator-action" data-annotate-action="convert" data-annotation-type="elide">Elide text</a>
        `;
      case 'link':
        return html`
          <a class="annotator-action" data-annotate-action="destroy">Remove link</a>
          <a class="annotator-action" data-annotate-action="edit" data-annotation-type="link">Edit link</a>
        `;
      case 'note':
        return html`
          <a class="annotator-action" data-annotate-action="destroy">Remove note</a>
          <a class="annotator-action" data-annotate-action="edit" data-annotation-type="elide">Edit note</a>
        `;
      }
    }

    newTemplate () {
      switch (this.newAnnotationType) {
      case 'link':
        return html`
          <form class="create-form" data-annotation-type="link">
            <input name="content" placeholder="Url to link to..."  />
          </form>
        `;
      case 'note':
        return html`
          <form class="create-form" data-annotation-type="note">
            <textarea name="content" placeholder="Note text..."></textarea>
            <input type="submit" value="Save note" />
          </form>
        `;
      }
    }

  menuTemplate () {
    return html`
      <a class="annotator-action" data-annotate-action="create" data-annotation-type="highlight">Highlight</a>
      <a class="annotator-action" data-annotate-action="create" data-annotation-type="elide">Elide</a>
      <a class="annotator-action" data-annotate-action="create" data-annotation-type="replace">Replace...</a>
      <a class="annotator-action" data-annotate-action="new" data-annotation-type="link">Add link...</a>
      <a class="annotator-action" data-annotate-action="new" data-annotation-type="note">Add note...</a>
    `;
  }

  calcTopOffset() {
    let wrapperRect = document.querySelector('.resource-wrapper').getBoundingClientRect();
    let viewportTop = window.scrollY - (wrapperRect.top + window.scrollY);

    let target = this.range || this.handle;
    this.targetRect = target ? target.getBoundingClientRect() : this.targetRect || {top: 0, bottom: 0};

    return Math.min(Math.max(this.targetRect.top - wrapperRect.top,
      viewportTop + 20),
      this.targetRect.bottom - wrapperRect.top);
  }

  select (range) {
    this.mode = 'create-menu';
    this.handle = null;

    this.offsets = offsetsForRange(range);
    if (!this.offsets) { return this.deactivate(); }

    this.range = range;

    this.render();
  }

  edit (handle) {
    this.mode = 'edit-handle';
    this.handle = handle;
    this.range = null;

    this.render();
  }

  new (type) {
    this.mode = 'new-form';
    this.newAnnotationType = type;

    this.render();
  }

  deactivate () {
    this.mode = 'inactive';
    this.handle = null;
    this.range = null;
    this.updateScroll.cancel();

    this.render();
  }

  doAnnotationAction (e) {
    switch (e.target.dataset.annotateAction) {
    case 'create':
      this.saveAnnotation(e.target.dataset.annotationType, this.offsets);
      break;
    case 'destroy':
      this.destroyAnnotation(this.handle.dataset.annotationId);
      break;
    case 'convert':
      this.convertAnnotation(this.handle.dataset.annotationId, e.target.dataset.annotationType);
      break;
    case 'new':
      this.new(e.target.dataset.annotationType);
      return;
    }
    this.deactivate();
  }

  submitAnnotationForm (e) {
    let field = e.target.querySelector('[name=content]');
    this.saveAnnotation(e.target.dataset.annotationType, this.offsets, field.value);

    this.deactivate();
  }

  saveAnnotation (type, offsets, content = null) {
    post(RAILS_ROUTES.resource_annotations_path(), {
      annotation: {
        kind: type,
        content: content,
        start_p: offsets.start.p,
        start_offset: offsets.start.offset,
        end_p: offsets.end.p,
        end_offset: offsets.end.offset
      }
    }, { scroll: false })
    .then( _ => window.getSelection().empty());
  }

  convertAnnotation (annotationId, type) {
    patch(RAILS_ROUTES.resource_annotation_path(annotationId), {
      annotation: {
        kind: type
      }
    }, { scroll: false })
    .then( _ => window.getSelection().empty());
  }

  updateAnnotation (annotationId, attrs) {
    patch(RAILS_ROUTES.resource_annotation_path(annotationId), {
      annotation: attrs
    }, { scroll: false })
    .then( _ => window.getSelection().empty());
  }

  destroyAnnotation (annotationId) {
    rest_delete(RAILS_ROUTES.resource_annotation_path(annotationId), {}, { scroll: false })
    .then( _ => window.getSelection().empty());
  }
}

// Find the start and end paragraph and offset for a selection
function offsetsForRange(range) {
  if (!(range.commonAncestorContainer.nodeType === document.TEXT_NODE ||
    range.commonAncestorContainer.tagName === 'P' ||
    range.commonAncestorContainer.classList.contains('case-text'))) {
    return null;
  }
  if (range.collapsed) { return null; }

  let startP = closestP(range.startContainer);
  let endP = closestP(range.endContainer);
  let startOffset = offsetInParagraph(startP, range.startContainer, range.startOffset);
  let endOffset = offsetInParagraph(endP, range.endContainer, range.endOffset);
  return  {
    start: {
      p: startP.dataset.pIdx,
      offset: startOffset
    },
    end: {
      p: endP.dataset.pIdx,
      offset: endOffset
    }
  };
}

// Find the closest containing P tag for the given element or text node
function closestP(node) {
  if (node.nodeType === document.TEXT_NODE) {
    return node.parentElement.closest('p');
  } else {
    return node.closest('p');
  }
}


function getCaretCharacterOffsetWithin(element) {
    var caretOffset = 0;
    var doc = element.ownerDocument || element.document;
    var win = doc.defaultView || doc.parentWindow;
    var sel;
    if (typeof win.getSelection != "undefined") {
        sel = win.getSelection();
        if (sel.rangeCount > 0) {
            var range = win.getSelection().getRangeAt(0);
            var preCaretRange = range.cloneRange();
            preCaretRange.selectNodeContents(element);
            preCaretRange.setEnd(range.endContainer, range.endOffset);
            caretOffset = preCaretRange.toString().length;
        }
    } else if ( (sel = doc.selection) && sel.type != "Control") {
        var textRange = sel.createRange();
        var preCaretTextRange = doc.body.createTextRange();
        preCaretTextRange.moveToElementText(element);
        preCaretTextRange.setEndPoint("EndToEnd", textRange);
        caretOffset = preCaretTextRange.text.length;
    }
    return caretOffset;
}

// Find the paragraph offset for an offset relative to the given text node
function offsetInParagraph(paragraph, targetNode, nodeOffset) {
  if (paragraph === targetNode) { // nodeOffset is the offset of the child node selected to
    let textOffset = 0;
    for (let childNode of paragraph.childNodes) {
      if (nodeOffset-- <= 0) { break; }
      textOffset += childNode.textContent.length;
    }
    return textOffset;
  } else if (targetNode.nodeType === document.TEXT_NODE) {
    let walker = document.createTreeWalker(
      paragraph,
      NodeFilter.SHOW_TEXT,
      null,
      false
    );
    for (let node = walker.nextNode(); node !== targetNode; node = walker.nextNode()) {
      nodeOffset += node.length;
      // if (walked++ > 100) throw new Error;
    }
    return nodeOffset;
  } else {
    let textOffset = 0;
    let walker = document.createTreeWalker(
      paragraph,
      NodeFilter.SHOW_ALL,
      null,
      false
    );
    for (let node = walker.nextNode(); node !== targetNode; node = walker.nextNode()) {
      if (node.nodeType === document.TEXT_NODE) { textOffset += node.length; }
      // if (walked++ > 100) throw new Error;
    }
    return textOffset;
  }
}
