import { parseHTML } from '../test_helpers';

import { isBlockLevel,
         isBR,
         isText,
         getLength,
         getAttrsMap,
         getClosestElement,
         getOffsetWithinParent } from 'libs/html_helpers';

import { mount } from '@vue/test-utils';
import TheAnnotator from 'components/TheAnnotator';

describe('isBlockLevel', () => {
  it('returns true when passed a block element', () => {
    expect(isBlockLevel(document.createElement('div'))).toBe(true);
  });

  it('returns false when passed an inline element', () => {
    expect(isBlockLevel(document.createElement('span'))).toBe(false);
  });
});

describe('isBR', () => {
  it('returns true when passed a br element', () => {
    expect(isBR(document.createElement('br'))).toBe(true);
  });

  it('returns false when passed a non-br element', () => {
    expect(isBR(document.createElement('span'))).toBe(false);
  });
});

describe('isText', () => {
  it('returns true when passed a text node', () => {
    expect(isText(document.createTextNode('hello world'))).toBe(true);
  });

  it('returns false when passed a non-text node', () => {
    expect(isText(document.createElement('span'))).toBe(false);
  });
});

describe('getLength', () => {
  it('returns correct text length for an element and its nested nodes', () => {
    expect(getLength(parseHTML('<div>Hello <em>W</em>orld</div>'))).toBe(11);
  });

  it('counts length of nodes hidden by styles', () => {
    expect(getLength(parseHTML('<div>Hello <em style="display:none;">W</em>orld</div>'))).toBe(11);
  });

  it('returns correct text length for a text node', () => {
    expect(getLength(document.createTextNode('hello world'))).toBe(11);
  });

  it('does not collapse repeated whitespace', () => {
    expect(getLength(document.createTextNode('hello      world'))).toBe(16);
  });

  it('returns 0 for a <br> element rather than 1, which is what innerText returns because it\'s read as whitespace', () => {
    expect(getLength(document.createElement('br'))).toBe(0);
  });
});

describe('getAttrsMap', () => {
  it('returns all attributes from an element as a map', () => {
    expect(getAttrsMap(parseHTML('<div id="foo" class="bar">Hello world</div>'))).toEqual({id: "foo", class: "bar"});
  });
});

describe('getClosestElement', () => {
  it('returns the same node when passed an element', () => {
    const el = document.createElement('div');
    expect(getClosestElement(el)).toBe(el);
  });

  it('returns the parent element when passed a text node', () => {
    const el = parseHTML('<div>Hello world</div>');
    expect(getClosestElement(el.childNodes[0])).toBe(el);
  });
});

describe('getOffsetWithinELement', () => {
  test('returns the correct offset for a child text node within its parent', () => {
    const parent = parseHTML('<div>foo <span>bar <em>buzz</em></span> fizz</div>');
    const child = parent.childNodes[2];
    expect(getOffsetWithinParent(parent, child)).toBe(12);
  });

  test('returns the correct offset for a child element node within its parent', () => {
    const parent = parseHTML('<div>foo <span>bar <em>buzz</em></span> fizz</div>');
    const child = parent.querySelector('em');
    expect(getOffsetWithinParent(parent, child)).toBe(8);
  });

  test('filters nodes for offset calculation based on optional parameter', () => {
    const parent = parseHTML('<div>foo <span>bar <em data-exclude-from-offset-calcs="true">buzz</em></span> fizz</div>');
    const child = parent.childNodes[2];
    const wrapper = mount(TheAnnotator);
    expect(getOffsetWithinParent(parent, child, wrapper.vm.contributesToOffsets)).toBe(8);
  });
});
