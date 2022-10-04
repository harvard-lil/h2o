const BLOCK_LEVEL_ELEMENTS = [
  "ADDRESS",
  "ARTICLE",
  "ASIDE",
  "BLOCKQUOTE",
  "DETAILS",
  "DIALOG",
  "DD",
  "DIV",
  "DL",
  "DT",
  "FIELDSET",
  "FIGCAPTION",
  "FIGURE",
  "FOOTER",
  "FORM",
  "H1",
  "H2",
  "H3",
  "H4",
  "H5",
  "H6",
  "HEADER",
  "HGROUP",
  "HR",
  "IFRAME",
  "IMG",
  "LI",
  "MAIN",
  "NAV",
  "OL",
  "P",
  "PRE",
  "SECTION",
  "TABLE",
  "UL"
];

export const isBlockLevel = (el) =>
  BLOCK_LEVEL_ELEMENTS.includes(el.tagName);

export const isElement = (node) =>
  node.nodeType == document.ELEMENT_NODE;

export const isText = (node) =>
  node.nodeType == document.TEXT_NODE;

export const isBR = (node) =>
  node.tagName == "BR" || node.tagName == "IMG";

export const getLength = (node) =>
  node.textContent.length;

export const getAttrsMap = (el) => {
  let nodelist = el.attributes;
  let attrmap = {};
  let i = 0;
  for (; i < nodelist.length; i++) {
    attrmap[nodelist[i].name] = nodelist[i].value;
  }
  return attrmap;
};

export const getClosestElement = (node) =>
  isText(node) ? node.parentNode : node;

  /**
   *
   * Get the character offset within the case text itself.
   *
   * @param {Node} parent The top-level parent, usually the selector `.case-text` that contains the entire case HTML
   * @param {Node} child The node where the selection took place.
   * @param {function} accept A filter function to accept or reject a node from inclusion in the treewalker
   * @returns {number} the offset
   */
export const getOffsetWithinParent = (parent, child, accept) => {
  const filter = accept ? {acceptNode: (node) => accept(node) ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT} : null;
  const walker = document.createTreeWalker(parent, NodeFilter.SHOW_ALL, filter);

  // Determine when to stop walking through the nodes to find the start position of the selection...
  const continueCondition = child.nodeType === document.TEXT_NODE ?
      // If the user started their selection in a text node, stop the iteration at the point when we get to that node
      (node) => node && node !== child:
      // If the user started their selection on an element boundary, stop at the containing element
      (node) => node && !child.contains(node)

  let offset = 0;
  let node = walker.nextNode();

  while (continueCondition(node)) {
    if (node.nodeType === document.TEXT_NODE) {
      offset += getLength(node);
    }
    node = walker.nextNode();
  }

  return offset;
};
