import { isText,
         getClosestElement} from "./html_helpers";

// Find the start and end paragraph and offset for a selection
export function offsetsForRanges(ranges) {
  if (!ranges ||
      ranges[0].collapsed ||
      !getClosestElement(ranges[0].commonAncestorContainer).closest(".case-text")) {
    return null;
  }

  return ["start", "end"].reduce((m, s, i) => {
    const container = ranges[i][`${s}Container`];
    const p = getClosestElement(container).closest('[data-index]');
    return {...m,
            [`${s}_paragraph`]: p.dataset.index,
            [`${s}_offset`]: offsetInParagraph(p, container, ranges[i][`${s}Offset`])};
  }, {});
}

export function getCaretCharacterOffsetWithin(element) {
    let caretOffset = 0;
    const doc = element.ownerDocument || element.document;
    const win = doc.defaultView || doc.parentWindow;
    let sel;
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
export function offsetInParagraph(paragraph, targetNode, nodeOffset) {
  if (paragraph === targetNode) { // nodeOffset is the offset of the child node selected to
    let textOffset = 0;
    for (let childNode of paragraph.childNodes) {
      if (nodeOffset-- <= 0) { break; }
      textOffset += childNode.textContent.length;
    }
    return textOffset;
  } else if (isText(targetNode)) {
    let walker = document.createTreeWalker(
      paragraph,
      NodeFilter.SHOW_TEXT,
      null,
      false
    );

    for (let node = walker.nextNode(); node !== targetNode; node = walker.nextNode()) {
      if (node.parentNode.closest("[data-exclude-from-offset-calcs='true']")) {
        continue;
      }
      nodeOffset += node.length;
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
      if (isText(node)) { textOffset += node.length; }
    }
    return textOffset;
  }
}
