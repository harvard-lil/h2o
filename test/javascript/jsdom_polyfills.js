// 'Implement' innerText in JSDOM: https://github.com/jsdom/jsdom/issues/1245
// When outside of a PRE element, replaces consecutive spaces
// with a single space, as a browser would
if(!('innerText' in Element.prototype)) {
  Object.defineProperty(Element.prototype, 'innerText', {get() {
    if(this.parentElement.tagName == 'PRE'){
      return this.textContent;
    } else {
      return this.textContent.replace(/ +/g, " ");
    }
  }});
}
