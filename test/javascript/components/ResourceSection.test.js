import ResourceSection from 'components/ResourceSection';

test('hello world', () => {
  expect('hello world').toMatch(/hello world/);
});

test('fix me', () => {
  expect('hello world').not.toMatch(/hello world/);
});
