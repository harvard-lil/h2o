// Find the start and end paragraph and offset for a selection
export function offsetsForRange(range) {
  if (!(range.commonAncestorContainer.nodeType === document.TEXT_NODE ||
    range.commonAncestorContainer.tagName === 'P' ||
    range.commonAncestorContainer.classList.contains('case-text'))) {
    return null;
  }
  if (range.collapsed) { return null; }

  let startParagraph = closestP(range.startContainer);
  let endParagraph = closestP(range.endContainer);
  let startOffset = offsetInParagraph(startParagraph, range.startContainer, range.startOffset);
  let endOffset = offsetInParagraph(endParagraph, range.endContainer, range.endOffset);
  return  {
    start: {
      p: startParagraph.dataset.pIdx,
      offset: startOffset
    },
    end: {
      p: endParagraph.dataset.pIdx,
      offset: endOffset
    }
  };
}

// Find the closest containing tag for the given element or text node
export function closestP(node) {
  if (node.nodeType === document.TEXT_NODE) {
    return node.parentElement.closest('.case-text > *');
  } else {
    return node.closest('.case-text > *');
  }
}

export function getCaretCharacterOffsetWithin(element) {
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
export function offsetInParagraph(paragraph, targetNode, nodeOffset) {
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
      if (node.parentNode.nodeName == "H2" ||
          node.parentNode.closest("[data-exclude-from-offset-calcs='true']")) {
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
      if (node.nodeType === document.TEXT_NODE) { textOffset += node.length; }
    }
    return textOffset;
  }
}
