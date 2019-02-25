import { parseHTML } from '../test_helpers';

import { isBlockLevel,
         isBR,
         isText,
         getLength,
         getAttrsMap,
         getClosestElement } from 'libs/html_helpers';

describe('isBlockLevel', () => {
  test('returns true when passed a block element', () => {
    expect(isBlockLevel(document.createElement('div'))).toBe(true);
  });

  test('returns false when passed an inline element', () => {
    expect(isBlockLevel(document.createElement('span'))).toBe(false);
  });
});

describe('isBR', () => {
  test('returns true when passed a br element', () => {
    expect(isBR(document.createElement('br'))).toBe(true);
  });

  test('returns false when passed a non-br element', () => {
    expect(isBR(document.createElement('span'))).toBe(false);
  });
});

describe('isText', () => {
  test('returns true when passed a text node', () => {
    expect(isText(document.createTextNode('hello world'))).toBe(true);
  });

  test('returns false when passed a non-text node', () => {
    expect(isText(document.createElement('span'))).toBe(false);
  });
});

describe('getLength', () => {
  test('returns correct text length for an element and its nested nodes', () => {
    expect(getLength(parseHTML('<div>Hello <em>W</em>orld</div>'))).toBe(11);
  });

  test('returns correct text length for a text node', () => {
    expect(getLength(document.createTextNode('hello world'))).toBe(11);
  });

  test('returns 0 a <br> element rather than 1, which is what innerText returns because it\s read as whitespace', () => {
    expect(getLength(document.createElement('br'))).toBe(0);
  });
});

describe('getAttrsMap', () => {
  test('returns all attributes from an element as a map', () => {
    expect(getAttrsMap(parseHTML('<div id="foo" class="bar">Hello world</div>'))).toEqual({id: "foo", class: "bar"});
  });
});

describe('getClosestElement', () => {
  test('returns the same node when passed an element', () => {
    const el = document.createElement('div');
    expect(getClosestElement(el)).toBe(el);
  });

  test('returns the parent element when passed a text node', () => {
    const el = parseHTML('<div>Hello world</div>');
    expect(getClosestElement(el.childNodes[0])).toBe(el);
  });
});
