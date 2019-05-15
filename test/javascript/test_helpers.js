export const parseHTML = (html) => {
  const parser = new DOMParser();
  const doc = parser.parseFromString(html, "text/html");
  return doc.body.children[0];
};

export const createText = (s) => document.createTextNode(s);

export const removeVueScopedCSSAttributes = (element) => {
  let attrNodes = document.evaluate('//*/attribute::*[starts-with(name(), "data-v-")]', element, null, XPathResult.UNORDERED_NODE_ITERATOR_TYPE, null);

  let attrNode;
  while((attrNode = attrNodes.iterateNext())) attrNode.ownerElement.removeAttributeNode(attrNode);
  return element;
};
