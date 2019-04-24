const transferAttributes = (src, dest) => {
    for(let i = 0; i < src.attributes.length; i++) {
        let attr = src.attributes[i];
        dest.setAttribute(attr.name, attr.value);
    }
};

const replaceTag = (el, newTag) => {
  let newEl = document.createElement(newTag);
  transferAttributes(el, newEl);
  newEl.innerHTML = el.innerHTML;
  el.parentNode.replaceChild(newEl, el);
};

const wrap = (el, wrapperTag) => {
  let wrapper = document.createElement(wrapperTag);
  el.parentNode.insertBefore(wrapper, el);
  wrapper.appendChild(el);
};

const unwrap = (el) => {
  let parent = el.parentNode;
  while (el.firstChild) parent.insertBefore(el.firstChild, el);
  parent.removeChild(el);
};

export const unwrapUndesiredTags = (doc) => {
  doc.querySelectorAll("article, section").forEach(unwrap);
  return doc;
};

export const emptyULToP = (doc) => {
  Array.from(doc.querySelectorAll("ul"))
       .filter((ul) => ul.querySelector(":not(li)") || ul.children.length == 0)
    .forEach(ul => replaceTag(ul, "p"));
  return doc;
};

export const wrapBareInlineTags = (doc) => {
  doc.querySelectorAll("body > :not(p):not(center):not(blockquote):not(article)")
      .forEach(el => wrap(el, "p"));
  return doc;
};

export const removeEmptyNodes = (doc) => {
  while(doc.querySelectorAll(":empty").length){
    doc.querySelectorAll(":empty").forEach(el => el.remove());
  };
  return doc;
};

const LAYOUT_ELEMENTS = [
  "ADDRESS",
  "ARTICLE",
  "ASIDE",
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
