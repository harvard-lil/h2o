// 'Implement' innerText in JSDOM: https://github.com/jsdom/jsdom/issues/1245
if(!('innerText' in Element.prototype)) {
  Object.defineProperty(Element.prototype,
                        'innerText',
                        {get() { return this.textContent; }});
}
