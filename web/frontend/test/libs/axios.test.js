import Axios from '../../config/axios';
import { handleImageUpload } from '../../libs/tinymce_extensions';

describe('shared Axios request encoding', () => {
  let adapter;
  let originalAdapter;

  beforeEach(() => {
    originalAdapter = Axios.defaults.adapter;
    adapter = vi.fn(async config => ({status: 200, data: {location: '/uploaded.png'}, config}));
    Axios.defaults.adapter = adapter;
  });
  afterEach(() => { Axios.defaults.adapter = originalAdapter; });

  it.each([
    ['/casebooks/1/new/link', {url: 'https://example.com/document.pdf?api=v2', section: '2'}],
    ['/casebooks/1/new/text', {name: 'Title', content: '<p>Body</p>', section: '2'}],
    ['/casebooks/1/settings', {submission_type: 'change_visibility', transition_to: 'Archived'}],
  ])('preserves form fields for %s', async (url, fields) => {
    const form = new FormData();
    Object.entries(fields).forEach(([key, value]) => form.append(key, value));
    await Axios.post(url, form);
    const request = adapter.mock.calls[0][0];
    expect(request.data).toBeInstanceOf(FormData);
    expect(Object.fromEntries(request.data)).toEqual(fields);
    expect(request.headers.getContentType()).not.toBe('application/json');
  });

  it('preserves uploaded image bytes and filename', async () => {
    const file = new File(['image bytes'], 'example.png', {type: 'image/png'});
    const location = await handleImageUpload({blob: () => file, filename: () => file.name, name: () => 'example'}, vi.fn());
    const request = adapter.mock.calls[0][0];
    expect(request.url).toBe('/image/');
    expect(request.data).toBeInstanceOf(FormData);
    const image = request.data.get('image');
    expect(image.name).toBe('example.png');
    expect(image.size).toBe(file.size);
    expect(image.type).toBe(file.type);
    expect(request.data.get('name')).toBe('example');
    expect(location).toBe('/uploaded.png');
  });

  it.each(['post', 'patch', 'put', 'delete'])('keeps JSON and method overrides for %s', async method => {
    await Axios.request({url: '/resources/1/annotations', method, data: {content: 'note'}});
    const request = adapter.mock.calls[0][0];
    expect(request.data).toBe('{"content":"note"}');
    expect(request.headers.getContentType()).toBe('application/json');
    expect(request.method).toBe('post');
    if (method !== 'post') expect(request.headers.get('X-HTTP-Method-Override')).toBe(method.toUpperCase());
  });
});
