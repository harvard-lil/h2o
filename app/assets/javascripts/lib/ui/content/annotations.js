import {html} from 'es6-string-html-template';
import {post} from 'lib/turbolinks/requests';
import throttle from 'lodash.throttle';
import Component from 'lib/ui/component'

let annotator = null;

document.addEventListener('turbolinks:load', e => {
  if (!document.querySelector('.case-text')) {
    annotator && annotator.destroy();
    annotator = null;
    return;
  }

  pushAnnotationHandles();
  annotator = new Annotator();
});


document.addEventListener('selectionchange', e => {
  if (!annotator) { return; }

  let selection = document.getSelection();
  if (selection.isCollapsed) {
    annotator.deactivate();
  } else {
    let range = selection.getRangeAt(0);
    annotator.activate(range);
  }
});

window.addEventListener('scroll', e => {
  if (annotator && annotator.active) {
    annotator.updateScroll();
  }
});

class Annotator extends Component {
  constructor (marker) {
    super({
      id: 'annotator',
      events: {
        'click .annotator-button': e => { this.doAnnotation(e); }
      }
    });


    this.marker = new SelectionMarker();
    this.updateScroll = throttle(this.render, 100, {leading: true, trailing: true});

    document.querySelector('.resource-wrapper').appendChild(this.el);
    this.render();
  }

  destroy () {
    super.destroy();
    this.updateScroll.cancel();
  }

  template () {
    return html`<div id="annotator" class="${this.active ? '' : 'hide'}" style="top: ${this.calcTopOffset()}px">
      <div class="annotator-inner">
        <a class="annotator-button" data-annotate-action="highlight">Highlight</a>
        <a class="annotator-button" data-annotate-action="elide">Elide</a>
        <a class="annotator-button" data-annotate-action="replace">Replace...</a>
        <a class="annotator-button" data-annotate-action="link">Add link...</a>
        <a class="annotator-button" data-annotate-action="note">Add note...</a>
      </div>
    </div>`
  }

  calcTopOffset() {
    let wrapperRect = document.querySelector('.resource-wrapper').getBoundingClientRect();
    let viewportTop = window.scrollY - (wrapperRect.top + window.scrollY);
    return Math.min(Math.max(this.marker.offsets.start,
      viewportTop + 20),
      this.marker.offsets.end);
  }

  activate (range) {
    this.active = true;

    this.offsets = offsetsForRange(range);
    if (!this.offsets) { return this.deactivate(); }

    this.marker.markRange(range);

    this.render();
  }

  deactivate () {
    this.active = false;
    this.updateScroll.cancel();

    this.render();
  }

  doAnnotation (e) {
    let action = e.target.dataset.annotateAction;
    this.saveAnnotation(action, this.offsets);
    this.deactivate();
  }

  saveAnnotation (action, offsets) {
    post(RAILS_ROUTES.resource_annotations_path(), {
      annotation: {
        kind: action,
        start_p: offsets.start.p,
        start_offset: offsets.start.offset,
        end_p: offsets.end.p,
        end_offset: offsets.end.offset
      }
    }, { scroll: false })
    .then( _ => window.getSelection().empty());
  }
}

class SelectionMarker extends Component {
  constructor () {
    super({});

    this.startEl = this.findOrCreateElement('annotation-marker-start');
    this.endEl = this.findOrCreateElement('annotation-marker-end');
    this.offsets = {start: 0, end: 0};
  }
  markRange (range) {
    // Rejoin split text nodes left at markers
    let parents = [this.startEl.parentElement, this.endEl.parentElement];
    this.releaseElements();
    for (let parent of parents) { parent && parent.normalize(); }

    range.insertNode(this.startEl);

    let endRange = range.cloneRange();
    endRange.collapse(false);
    endRange.insertNode(this.endEl);

    this.calcOffsets();
  }
  releaseElements () {
    this.startEl.parentElement && this.startEl.parentElement.removeChild(this.startEl);
    this.endEl.parentElement && this.endEl.parentElement.removeChild(this.endEl);
  }
  calcOffsets () {
    this.offsets = {
      start: this.startEl.offsetTop,
      end: this.endEl.offsetTop
    };
  }
}

// After rendering, push over annotation margin handles which land on the same line
function pushAnnotationHandles() {
  let handles = document.querySelectorAll('.annotation-handle');
  let prevRect = null;
  for (let handle of handles) {
    let rect = handle.getBoundingClientRect();
    if (prevRect && rect.top === prevRect.top) {
      handle.style.right = `${0 - (prevRect.left + prevRect.width - rect.left + 2)}px`;
      rect = handle.getBoundingClientRect();
    }
    prevRect = rect;
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
