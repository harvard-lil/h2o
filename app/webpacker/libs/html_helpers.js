const replaceTag = (el, newTag) => {
  let newEl = document.createElement(newTag);
  newEl.innerHTML = el.innerHTML;
  el.parentNode.replaceChild(newEl, el);
};

const unwrap = (el) => {
  let parent = el.parentNode;
  while (el.firstChild) parent.insertBefore(el.firstChild, el);
  parent.removeChild(el);
};

export const unwrapUndesiredTags = (doc) => {
  doc.querySelectorAll("article, section, aside").forEach(unwrap);
  return doc;
};

export const emptyUlToP = (doc) => {
  Array.from(doc.querySelectorAll("ul"))
       .filter((ul) => ul.querySelector(":not(li)") || ul.children.length == 0)
    .forEach(ul => replaceTag(ul, "p"));
  return doc;
};

export const wrapBareInlineTags = (doc) => {
  doc.querySelectorAll("body > :not(p):not(center):not(blockquote):not(article)")
      .forEach(el => replaceTag(el, "p"));
  return doc;
};

export const removeEmptyNodes = (doc) => {
  while(doc.querySelectorAll(":empty").length){
    doc.querySelectorAll(":empty").forEach(el => el.remove());
  };
  return doc;
};
