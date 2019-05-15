import { spy } from 'sinon';

import { parseHTML,
         createText } from '../test_helpers';
import { getLength } from 'libs/html_helpers';
import { isFootnoteLink,
         transformToTuplesWithOffsets,
         splitTextAt,
         sequentialInlineNodesWithinRange,
         tupleToVNode,
         filterAndSplitNodeList,
         annotationBreakpoints } from 'libs/resource_node_parsing';

const stringifyTuple = t => [t[0].outerHTML || t[0].textContent, t[1], t[2]];

const DEFAULT_ANNOTATION = Object.freeze({
  "id": 1,
  "resource_id": 1,
  "start_offset": 0,
  "end_offset": Number.MAX_SAFE_INTEGER,
  "kind": "highlight",
  "content": null
});

describe('isFootnoteLink', () => {
  it('returns true when passed a link element with a hash as well as the same origin and path as the current location', () => {
    expect(isFootnoteLink(parseHTML(`<a href="${location.href}#foo"></a>`))).toBe(true);
  });

  it('returns false when the link element is missing a hash', () => {
    expect(isFootnoteLink(parseHTML(`<a href="${location.pathname}"></a>`))).toBe(false);
  });

  it('returns false when the link element is has a different origin', () => {
    expect(isFootnoteLink(parseHTML(`<a href="http://example.com/${location.pathname}"></a>`))).toBe(false);
  });

  it('returns false when the link element has a different path', () => {
    expect(isFootnoteLink(parseHTML('<a href="/foo"></a>'))).toBe(false);
  });

  it('returns false when passed a non-link node', () => {
    expect(isFootnoteLink(createText('foo'))).toBe(false);
  });
});

describe('transformToTuplesWithOffsets', () => {
  it('returns tuples with three elements (node, start, end) using the previous end in the list to calculate the next node\'s end position', () => {
    const nodes = Array.from(parseHTML('<ol><li>first</li><li>second</li><li>third</li><</ol>').children);
    expect(nodes.reduce(transformToTuplesWithOffsets(0), [])).toEqual([
      [nodes[0], 0, 5],
      [nodes[1], 5, 11],
      [nodes[2], 11, 16],
    ]);
  });
});

describe('splitTextAt', () => {
  it('takes a Text node and splits it at the specified breakpoints', () => {
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

  it('ignores breakpoints that fall outside of the specified node', () => {
    const text = createText('Hello world');
    const start = 1;
    const tuple = [text, start, start + getLength(text)];
    const breakpoints = [0, 9999];
    expect(splitTextAt(breakpoints, tuple)).toEqual([tuple]);
  });

  it('ignores breakpoints at existing boundaries', () => {
    const text = createText('Hello world');
    const start = 1;
    const tuple = [text, start, start + getLength(text)];
    const breakpoints = [tuple[1], tuple[2]];
    expect(splitTextAt(breakpoints, tuple)).toEqual([tuple]);
  });
});

describe('sequentialInlineNodesWithinRange', () => {
  it('drops tuples that fall entirely outside of the specified range', () => {
    const tuples = Array.from(
      parseHTML('<div>Foo <span>bar</span> fizz<em> buzz</em>.</div>').childNodes
    ).reduce(transformToTuplesWithOffsets(0), []);
    expect(sequentialInlineNodesWithinRange(tuples, 4, 12)).toEqual(tuples.slice(1, 3));
  });

  it('drops tuples that fall partially outside of the specified range', () => {
    const tuples = Array.from(
      parseHTML('<div>Foo <span>bar</span> fizz<em> buzz</em>.</div>').childNodes
    ).reduce(transformToTuplesWithOffsets(0), []);
    expect(sequentialInlineNodesWithinRange(tuples, 2, 14)).toEqual(tuples.slice(1, 3));
  });

  it('stops at first block level element within range', () => {
    const tuples = Array.from(
      parseHTML('<div>Foo <span>bar</span> fizz<div> buzz</div>.</div>').childNodes
    ).reduce(transformToTuplesWithOffsets(0), []);
    expect(sequentialInlineNodesWithinRange(tuples, 2, 9999)).toEqual(tuples.slice(1, 3));
  });

  it('ignores block level elements outside of range', () => {
    const tuples = Array.from(
      parseHTML('<div>Foo <div>bar</div> fizz<em> buzz</em><div>.</div></div>').childNodes
    ).reduce(transformToTuplesWithOffsets(0), []);
    expect(sequentialInlineNodesWithinRange(tuples, 7, 17)).toEqual(tuples.slice(2, 4));
  });
});

describe('tupleToVNode', () => {
  it('returns a string when passed a Text node, which Vue will convert to a VNode on its own', () => {
    const s = 'foobar';
    expect(tupleToVNode()([createText(s), 0, s.length])).toEqual(s);
  });

  it('returns the VNode untouched when passed a VNode', () => {
    const mockVNode = {};
    expect(tupleToVNode()([mockVNode, 0, 0])).toBe(mockVNode);
  });

  it('returns a VNode, of the same tag type, when passed an HTMLElement', () => {
    const tag = 'DIV';
    const id = 'foo';
    const child = 'bar';
    const el = parseHTML(`<${tag} id="${id}">${child}</${tag}>`);
    const mockVueCreateElement = spy((tagName, data, children) => {});

    tupleToVNode(mockVueCreateElement, [])([el, 0, getLength(el)]);

    const [tagName, data, children] = mockVueCreateElement.args[0];
    expect(tagName).toBe(tag);
    expect(data).toEqual({attrs: {id: id}});
    expect(children).toEqual([child]);
  });

  it('returns a FootnoteLink VNode when passed an HTMLElement that looks like a footnote', () => {
    const el = parseHTML(`<a href="${location.href}#foo">bar</a>`);
    const mockVueCreateElement = spy((tag, data, children) => {});

    tupleToVNode(mockVueCreateElement, [])([el, 0, getLength(el)]);

    const [tagName] = mockVueCreateElement.args[0];
    expect(tagName).toBe('footnote-link');
  });
});

describe('annotationBreakpoints', () => {
  it('collects both starting and ending offsets', () => {
    const annotations = [{...DEFAULT_ANNOTATION, start_offset: 1, end_offset: 5}];
    expect(annotationBreakpoints(annotations, 0, 100)).toEqual([1, 5]);
  });

  it('removes duplicate breakpoints from the set', () => {
    const annotations = [
      {...DEFAULT_ANNOTATION, start_offset: 1, end_offset: 5},
      {...DEFAULT_ANNOTATION, start_offset: 5, end_offset: 10}
    ];
    expect(annotationBreakpoints(annotations, 0, 100)).toEqual([1, 5, 10]);
  });

  it('sorts breakpoints lowest to highest', () => {
    const annotations = [
      {...DEFAULT_ANNOTATION, start_offset: 1, end_offset: 10},
      {...DEFAULT_ANNOTATION, start_offset: 5, end_offset: 7}
    ];
    expect(annotationBreakpoints(annotations, 0, 100)).toEqual([1, 5, 7, 10]);
  });
});

describe('filterAndSplitNodeList', () => {
  it('returns an array of tuples', () => {
    const node = parseHTML('<div>Foo <em>bar</em> fizz</div>');
    const tuples = filterAndSplitNodeList([], node.childNodes, 0, getLength(node));
    expect(tuples.map(stringifyTuple)).toEqual([
      ['Foo ', 0, 4],
      ['<em>bar</em>', 4, 7],
      [' fizz', 7, 12]
    ]);
  });

  it('filters out nodes that aren\'t text or layout elements', () => {
    const node = parseHTML('<div>Foo <!-- comment --><script>let noop;</script><style>.noop {}</style><em>bar</em></div>');
    const tuples = filterAndSplitNodeList([], node.childNodes, 0, getLength(node));
    expect(tuples.map(stringifyTuple)).toEqual([
      ['Foo ', 0, 4],
      ['<em>bar</em>', 4, 7]
    ]);
  });

  it('breaks text at annotation breakpoints');
});
