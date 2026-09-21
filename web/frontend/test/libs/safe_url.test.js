import { safeURL } from '../../libs/safe_url';

it.each(['javascript:alert(1)', 'data:text/html,test', 'https://[invalid'])('rejects unsafe or malformed URLs: %s', value => {
  expect(safeURL(value)).toBeUndefined();
});

it.each(['https://example.com/', '/reading/', 'mailto:author@example.com'])('preserves supported URLs: %s', value => {
  expect(safeURL(value)).toBe(value);
});
