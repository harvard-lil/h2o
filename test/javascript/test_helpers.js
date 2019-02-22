export const parseHTML = (html) => {
  const parser = new DOMParser();
  const doc = parser.parseFromString(html, "text/html");
  return doc.body.children[0];
};

export const createText = (s) => document.createTextNode(s);
