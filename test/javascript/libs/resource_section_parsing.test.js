import { parseNode } from '../test_helpers';
import { isFootnoteLink,
         transformToTuplesWithOffsets} from 'libs/resource_section_parsing';

describe('isFootnoteLink', () => {
  test('returns true when passed a link element with a hash as well as the same origin and path as the current location', () => {
    expect(isFootnoteLink(parseNode(`<a href="#foo"></a>`))).toBe(false);
  });

  test('returns false when the link element is missing a hash', () => {
    expect(isFootnoteLink(parseNode(`<a href="${location.pathname}"></a>`))).toBe(false);
  });

  test('returns false when the link element is has a different origin', () => {
    expect(isFootnoteLink(parseNode(`<a href="http://example.com/${location.pathname}"></a>`))).toBe(false);
  });

  test('returns false when the link element has a different path', () => {
    expect(isFootnoteLink(parseNode('<a href="/foo"></a>'))).toBe(false);
  });

  test('returns false when passed a non-link node', () => {
    expect(isFootnoteLink(document.createTextNode('Hello world'))).toBe(false);
  });
});

describe('transformToTuplesWithOffsets', () => {
  test('returns tuples with three elements (node, start, end) using the previous end in the list to calculate the next node\'s end position', () => {
    const nodes = Array.from(parseNode('<ol><li>first</li><li>second</li><li>third</li><</ol>').children);
    expect(nodes.reduce(transformToTuplesWithOffsets(0), [])).toEqual([
      [nodes[0], 0, 5],
      [nodes[1], 5, 11],
      [nodes[2], 11, 16],
    ]);
  });
});
