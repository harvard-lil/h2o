import axios, { AxiosError } from 'axios';
import { installPreclearance } from '../../libs/preclearance';

function blocked(config, status = 403, headers = {'cf-mitigated': 'challenge'}) {
  return Promise.reject(new AxiosError('Blocked', 'ERR_BAD_REQUEST', config, null,
    {status, headers, config}));
}

describe('challenge retries', () => {
  beforeEach(() => { window.H2O_TURNSTILE_SITE_KEY = 'test'; });
  afterEach(() => { delete window.H2O_TURNSTILE_SITE_KEY; vi.restoreAllMocks(); });
  it('replays a challenged write once, retaining its body and method override', async () => {
    const verify = vi.fn().mockResolvedValue();
    const adapter = vi.fn().mockImplementationOnce(blocked).mockImplementation(async config => ({status: 201, data: 'saved', config}));
    const client = axios.create({adapter});
    installPreclearance(client, verify);
    await client.post('/resources/1/annotations', {content: 'note'}, {headers: {'X-HTTP-Method-Override': 'PATCH'}});
    expect(adapter).toHaveBeenCalledTimes(2);
    expect(verify).toHaveBeenCalledTimes(1);
    const retry = adapter.mock.calls[1][0];
    expect(retry.data).toBe('{"content":"note"}');
    expect(retry.method).toBe('post');
    expect(retry.headers['X-HTTP-Method-Override']).toBe('PATCH');
  });
  it.each([
    [403, {}, '/resources/1/annotations'],
    [500, {'cf-mitigated': 'challenge'}, '/resources/1/annotations'],
    [403, {'cf-mitigated': 'challenge'}, 'https://other.example/'],
  ])('does not replay ordinary failures or external requests', async (status, headers, url) => {
    const verify = vi.fn();
    const adapter = vi.fn(config => blocked(config, status, headers));
    const client = axios.create({adapter});
    installPreclearance(client, verify);
    await expect(client.get(url)).rejects.toThrow();
    expect(adapter).toHaveBeenCalledTimes(1);
    expect(verify).not.toHaveBeenCalled();
  });
  it('does not loop if the retried request is challenged again', async () => {
    vi.spyOn(window, 'alert').mockImplementation(() => {});
    const verify = vi.fn().mockResolvedValue();
    const adapter = vi.fn(blocked);
    const client = axios.create({adapter});
    installPreclearance(client, verify);
    await expect(client.get('/resources/1/annotations')).rejects.toThrow();
    expect(adapter).toHaveBeenCalledTimes(2);
    expect(verify).toHaveBeenCalledTimes(1);
  });
  it('does not replay after cancellation', async () => {
    const adapter = vi.fn(blocked);
    const client = axios.create({adapter});
    installPreclearance(client, () => Promise.reject(new Error('Cancelled')));
    await expect(client.post('/resources/1/annotations', {})).rejects.toThrow('Cancelled');
    expect(adapter).toHaveBeenCalledTimes(1);
  });
  it('is inactive until configured', async () => {
    window.H2O_TURNSTILE_SITE_KEY = '';
    const verify = vi.fn();
    const client = axios.create({adapter: blocked});
    installPreclearance(client, verify);
    await expect(client.get('/resources/1/annotations')).rejects.toThrow();
    expect(verify).not.toHaveBeenCalled();
  });
});

describe('verification dialog', () => {
  let options;
  beforeEach(() => {
    window.H2O_TURNSTILE_SITE_KEY = 'test';
    window.turnstile = {
      render: vi.fn((element, config) => { options = config; return 'widget'; }),
      remove: vi.fn(),
    };
    HTMLDialogElement.prototype.showModal = function() { this.open = true; };
    HTMLDialogElement.prototype.close = function() { this.open = false; };
  });
  afterEach(() => {
    delete window.H2O_TURNSTILE_SITE_KEY;
    delete window.turnstile;
    vi.unstubAllGlobals();
  });
  it('shares verification and releases waiting requests on widget success', async () => {
    const { verifyBrowser } = await import('../../libs/preclearance');
    vi.stubGlobal('fetch', vi.fn());
    const first = verifyBrowser();
    const second = verifyBrowser();
    expect(first).toBe(second);
    await Promise.resolve();
    expect(window.turnstile.render).toHaveBeenCalledTimes(1);
    await options.callback('test-token');
    await first;
    expect(fetch).not.toHaveBeenCalled();
    expect(document.querySelector('#browser-verification')).toBeNull();
    expect(window.turnstile.remove).toHaveBeenCalledWith('widget');
  });
  it('cancellation prevents a late verification callback from releasing requests', async () => {
    const { verifyBrowser } = await import('../../libs/preclearance');
    vi.stubGlobal('fetch', vi.fn());
    const pending = verifyBrowser();
    const rejected = expect(pending).rejects.toThrow('cancelled');
    await Promise.resolve();
    document.querySelector('#browser-verification button').click();
    await options.callback('late-token');
    await rejected;
    expect(fetch).not.toHaveBeenCalled();
  });
  it.each(['error-callback', 'expired-callback', 'timeout-callback'])('%s keeps requests paused even after a late success', async callback => {
    const { verifyBrowser } = await import('../../libs/preclearance');
    vi.stubGlobal('fetch', vi.fn());
    const pending = verifyBrowser();
    const rejected = expect(pending).rejects.toThrow('verification failed');
    await Promise.resolve();
    options[callback]();
    await options.callback('late-token');
    expect(document.querySelector('#browser-verification').textContent).toContain('Verification failed');
    document.querySelector('#browser-verification button').click();
    await rejected;
  });
});
