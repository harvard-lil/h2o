const LAYOUT_ELEMENTS = [
  "ADDRESS",
  "ARTICLE",
  "ASIDE",
  "CENTER", // this is deprecated but appears quite a bit in case.law texts
  "FOOTER",
  "HEADER",
  "H1",
  "H2",
  "H3",
  "H4",
  "H5",
  "H6",
  "HGROUP",
  "MAIN",
  "NAV",
  "SECTION",
  "BLOCKQUOTE",
  "DD",
  "DIR",
  "DIV",
  "DL",
  "DT",
  "FIGCAPTION",
  "FIGURE",
  "HR",
  "LI",
  "MAIN",
  "OL",
  "P",
  "PRE",
  "UL",
  "A",
  "ABBR",
  "B",
  "BDI",
  "BDO",
  "BR",
  "CITE",
  "CODE",
  "DATA",
  "DFN",
  "EM",
  "I",
  "KBD",
  "MARK",
  "Q",
  "RB",
  "RP",
  "RT",
  "RTC",
  "RUBY",
  "S",
  "SAMP",
  "SMALL",
  "SPAN",
  "STRONG",
  "SUB",
  "SUP",
  "TIME",
  "TT",
  "U",
  "VAR",
  "WBR",
  "DEL",
  "INS",
  "CAPTION",
  "COL",
  "COLGROUP",
  "TABLE",
  "TBODY",
  "TD",
  "TFOOT",
  "TH",
  "THEAD",
  "TR"
];

export const isLayoutElement = (el) =>
  LAYOUT_ELEMENTS.includes(el.tagName);

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
  node.tagName == "BR";

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

export const getOffsetWithinParent = (parent, child, accept) => {
  const filter = accept ? {acceptNode: (node) => accept(node) ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT} : null;
  const walker = document.createTreeWalker(parent, NodeFilter.SHOW_TEXT, filter);
  let offset = 0;
  for (let node = walker.nextNode();
       (isText(child) && node !== child) || !child.contains(node);
       node = walker.nextNode()) {
    offset += getLength(node);
  }
  return offset;
};
