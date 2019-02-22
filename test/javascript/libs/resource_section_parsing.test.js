import { parseNode } from '../test_helpers';
import { isFootnoteLink } from 'libs/resource_section_parsing';

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
