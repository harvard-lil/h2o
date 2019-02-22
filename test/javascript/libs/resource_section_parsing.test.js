import { parseHTML,
         createText } from '../test_helpers';
import { getLength } from 'libs/html_helpers';
import { isFootnoteLink,
         transformToTuplesWithOffsets,
         splitTextAt,
         sequentialInlineNodesWithinRange,
         tupleToVNode } from 'libs/resource_section_parsing';

const stringifyTuple = t => [t[0].outerHTML || t[0].textContent, t[1], t[2]];

describe('isFootnoteLink', () => {
  test('returns true when passed a link element with a hash as well as the same origin and path as the current location', () => {
    expect(isFootnoteLink(parseHTML(`<a href="${location.href}#foo"></a>`))).toBe(true);
  });

  test('returns false when the link element is missing a hash', () => {
    expect(isFootnoteLink(parseHTML(`<a href="${location.pathname}"></a>`))).toBe(false);
  });

  test('returns false when the link element is has a different origin', () => {
    expect(isFootnoteLink(parseHTML(`<a href="http://example.com/${location.pathname}"></a>`))).toBe(false);
  });

  test('returns false when the link element has a different path', () => {
    expect(isFootnoteLink(parseHTML('<a href="/foo"></a>'))).toBe(false);
  });

  test('returns false when passed a non-link node', () => {
    expect(isFootnoteLink(createText('foo'))).toBe(false);
  });
});

describe('transformToTuplesWithOffsets', () => {
  test('returns tuples with three elements (node, start, end) using the previous end in the list to calculate the next node\'s end position', () => {
    const nodes = Array.from(parseHTML('<ol><li>first</li><li>second</li><li>third</li><</ol>').children);
    expect(nodes.reduce(transformToTuplesWithOffsets(0), [])).toEqual([
      [nodes[0], 0, 5],
      [nodes[1], 5, 11],
      [nodes[2], 11, 16],
    ]);
  });
});

describe('splitTextAt', () => {
  test('takes a Text node and splits it at the specified breakpoints', () => {
    const text = createText('Hello world');
    const start = 1;
    const tuple = [text, start, start + getLength(text)];
    const breakpoints = [3, 5];
    expect(splitTextAt(breakpoints, tuple).map(stringifyTuple)).toEqual([
      ['He', 1, breakpoints[0]],
      ['ll', ...breakpoints],
      ['o world', breakpoints[1], 12]
    ]);
  });

  test('ignores breakpoints that fall outside of the specified node', () => {
    const text = createText('Hello world');
    const start = 1;
    const tuple = [text, start, start + getLength(text)];
    const breakpoints = [0, 9999];
    expect(splitTextAt(breakpoints, tuple)).toEqual([tuple]);
  });

  test('ignores breakpoints at existing boundaries', () => {
    const text = createText('Hello world');
    const start = 1;
    const tuple = [text, start, start + getLength(text)];
    const breakpoints = [tuple[1], tuple[2]];
    expect(splitTextAt(breakpoints, tuple)).toEqual([tuple]);
  });
});

describe('sequentialInlineNodesWithinRange', () => {
  test('drops tuples that fall entirely outside of the specified range', () => {
    const tuples = Array.from(
      parseHTML('<div>Foo <span>bar</span> fizz<em> buzz</em>.</div>').childNodes
    ).reduce(transformToTuplesWithOffsets(0), []);
    expect(sequentialInlineNodesWithinRange(tuples, 4, 12)).toEqual(tuples.slice(1, 3));
  });

  test('drops tuples that fall partially outside of the specified range', () => {
    const tuples = Array.from(
      parseHTML('<div>Foo <span>bar</span> fizz<em> buzz</em>.</div>').childNodes
    ).reduce(transformToTuplesWithOffsets(0), []);
    expect(sequentialInlineNodesWithinRange(tuples, 2, 14)).toEqual(tuples.slice(1, 3));
  });

  test('stops at first block level element within range', () => {
    const tuples = Array.from(
      parseHTML('<div>Foo <span>bar</span> fizz<div> buzz</div>.</div>').childNodes
    ).reduce(transformToTuplesWithOffsets(0), []);
    expect(sequentialInlineNodesWithinRange(tuples, 2, 9999)).toEqual(tuples.slice(1, 3));
  });

  test('ignores block level elements outside of range', () => {
    const tuples = Array.from(
      parseHTML('<div>Foo <div>bar</div> fizz<em> buzz</em><div>.</div></div>').childNodes
    ).reduce(transformToTuplesWithOffsets(0), []);
    expect(sequentialInlineNodesWithinRange(tuples, 7, 17)).toEqual(tuples.slice(2, 4));
  });
});

describe('tupleToVNode', () => {
  test('returns a string when passed a Text node, which Vue will convert to a VNode on its own', () => {
    const s = 'foobar';
    expect(tupleToVNode(null, 0)([createText(s), 0, s.length])).toEqual(s);
  });

  test('returns the VNode untouched when passed a VNode', () => {
    const mockVNode = {};
    expect(tupleToVNode(null, 0)([mockVNode, 0, 0])).toBe(mockVNode);
  });

  test('returns a VNode when passed an HTMLElement, of the same tag type', () => {
    const tag = 'DIV';
    const id = 'foo';
    const child = 'bar';
    const el = parseHTML(`<${tag} id="${id}">${child}</${tag}>`);
    const mockVueCreateElement = jest.fn((tagName, data, children) => {});

    tupleToVNode(mockVueCreateElement, 0)([el, 0, getLength(el)]);

    const [tagName, data, children] = mockVueCreateElement.mock.calls[0];
    expect(tagName).toBe(tag);
    expect(data).toEqual({attrs: {id: id}});
    expect(children).toEqual([child]);
  });

  test('returns a FootnoteLink VNode when passed an HTMLElement that looks like a footnote', () => {
    const el = parseHTML(`<a href="${location.href}#foo">bar</a>`);
    const mockVueCreateElement = jest.fn((tag, data, children) => {});

    tupleToVNode(mockVueCreateElement, 0)([el, 0, getLength(el)]);

    const [tagName] = mockVueCreateElement.mock.calls[0];
    expect(tagName).toBe('footnote-link');
  });
});
