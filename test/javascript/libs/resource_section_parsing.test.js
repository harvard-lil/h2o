import { parseHTML,
         createText } from '../test_helpers';
import { getLength } from 'libs/html_helpers';
import { isFootnoteLink,
         transformToTuplesWithOffsets,
         splitTextAt } from 'libs/resource_section_parsing';

const stringifyTuple = t => [t[0].outerHTML || t[0].textContent, t[1], t[2]];

describe('isFootnoteLink', () => {
  test('returns true when passed a link element with a hash as well as the same origin and path as the current location', () => {
    expect(isFootnoteLink(parseHTML(`<a href="#foo"></a>`))).toBe(false);
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
