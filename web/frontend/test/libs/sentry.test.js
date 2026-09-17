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

describe('expected request failures', () => {
  afterEach(() => vi.restoreAllMocks());
  it('drops only the typed verification cancellation', async () => {
    const { VerificationCancelledError } = await import('../../libs/requestErrors');
    expect(beforeSend({}, {originalException: new VerificationCancelledError()})).toBeNull();
    const event = {message: 'Browser verification cancelled.'};
    expect(beforeSend(event, {originalException: new Error(event.message)})).toBe(event);
  });
  it.each(['YandexBot/3.0', 'YandexAccessibilityBot/3.0'])('drops confirmed abort noise from %s', userAgent => {
    vi.spyOn(navigator, 'userAgent', 'get').mockReturnValue(userAgent);
    expect(beforeSend({exception: {values: [{type: 'AxiosError', value: 'Request aborted'}]}})).toBeNull();
    const other = {exception: {values: [{type: 'AxiosError', value: 'Network Error'}]}};
    expect(beforeSend(other)).toBe(other);
  });
  it('keeps real-browser aborts', () => {
    vi.spyOn(navigator, 'userAgent', 'get').mockReturnValue('Mozilla/5.0 Chrome/152');
    const event = {exception: {values: [{type: 'AxiosError', value: 'Request aborted'}]}};
    expect(beforeSend(event)).toBe(event);
  });
});
