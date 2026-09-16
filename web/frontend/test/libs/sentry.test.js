import { beforeSend } from '../../config/sentry';

describe('Sentry extension filtering', () => {
  const zotero = {value: 'Zotero Connector: Failed to send message i18n.getStrings to background page. It may be dead.'};
  it('drops the confirmed Zotero background-page error', () => {
    expect(beforeSend({exception: {values: [zotero]}})).toBeNull();
  });
  it.each([
    {},
    {message: 'Request failed with status code 403'},
    {exception: {values: [{value: 'Network Error'}]}},
    {exception: {values: [{value: 'Cannot read properties of undefined'}]}},
    {exception: {values: [zotero, {value: 'Application error'}]}},
    {exception: {values: [{value: 'Zotero Connector: different error'}]}},
  ])('retains other errors: %j', event => {
    expect(beforeSend(event)).toBe(event);
  });
});
