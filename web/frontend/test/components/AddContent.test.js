import { mount, flushPromises } from '@vue/test-utils';
import { AxiosError } from 'axios';
import Axios from '../../config/axios';

vi.mock('../../libs/urls', () => ({default: {url: () => () => '/unused'}}));
import AddContent from '../../components/AddContent.vue';

const Modal = {template: '<div><slot name="body" /></div>'};
const Editor = {
  props: ['value'],
  emits: ['input'],
  template: '<textarea :value="value" @input="$emit(\'input\', $event.target.value)" />',
};

describe('Add Content popup', () => {
  let wrapper;
  let adapter;
  let originalAdapter;

  beforeEach(() => {
    originalAdapter = Axios.defaults.adapter;
    adapter = vi.fn(async config => {
      throw new AxiosError('Bad Request', 'ERR_BAD_REQUEST', config, null, {status: 400, data: {}, config});
    });
    Axios.defaults.adapter = adapter;
    wrapper = mount(AddContent, {
      props: {casebook: '123', section: '456'},
      global: {stubs: {Modal, editor: Editor, LegalDocumentSearch: true}},
    });
  });
  afterEach(() => {
    wrapper.unmount();
    Axios.defaults.adapter = originalAdapter;
  });

  async function openTab(tab) {
    await wrapper.find('.add-resource').trigger('click');
    await wrapper.findAll('.search-tab')[tab === 'link' ? 2 : 1].trigger('click');
  }

  it('submits the link and section as form fields and preserves input on failure', async () => {
    await openTab('link');
    await wrapper.find('[name="url"]').setValue('https://example.com/document.pdf?api=v2');
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    const request = adapter.mock.calls[0][0];
    expect(request.url).toBe('/casebooks/123/new/link');
    expect(request.data).toBeInstanceOf(FormData);
    expect(Object.fromEntries(request.data)).toEqual({url: 'https://example.com/document.pdf?api=v2', section: '456'});
    expect(wrapper.find('[role="alert"]').text()).toContain('could not be completed');
    expect(wrapper.find('[name="url"]').element.value).toContain('document.pdf?api=v2');
    expect(wrapper.find('[type="submit"]').element.disabled).toBe(false);
  });

  it('submits custom content from the editor as form fields', async () => {
    await openTab('text');
    await wrapper.find('[name="name"]').setValue('Example title');
    await wrapper.find('textarea').setValue('<p>Example body</p>');
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    const request = adapter.mock.calls[0][0];
    expect(request.url).toBe('/casebooks/123/new/text');
    expect(request.data).toBeInstanceOf(FormData);
    expect(Object.fromEntries(request.data)).toEqual({name: 'Example title', content: '<p>Example body</p>', section: '456'});
    expect(wrapper.find('textarea').element.value).toBe('<p>Example body</p>');
  });

  it.each([
    {response: {data: '<html>Server error</html>'}},
    new Error('Network Error'),
    {response: {data: {url: []}}},
    {response: {data: {url: ['unexpected error format']}}},
    {response: {data: {name: [{message: 'Title is too long'}]}}},
  ])('shows a fallback for an error without displayable fields: %j', async error => {
    adapter.mockRejectedValue(error);
    await openTab('link');
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    expect(wrapper.find('[role="alert"]').exists()).toBe(true);
    expect(wrapper.find('[type="submit"]').element.disabled).toBe(false);
  });

  it('renders field errors and clears them while a retry is pending', async () => {
    adapter.mockRejectedValue({response: {data: {url: [{message: 'Enter a valid URL.'}]}}});
    await openTab('link');
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    expect(wrapper.text()).toContain('Enter a valid URL.');
    expect(wrapper.find('[role="alert"]').exists()).toBe(false);
    let reject;
    adapter.mockImplementation(() => new Promise((resolve, fail) => { reject = fail; }));
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    expect(wrapper.text()).not.toContain('Enter a valid URL.');
    expect(wrapper.find('[type="submit"]').element.disabled).toBe(true);
    reject(new Error('Network Error'));
    await flushPromises();
  });
});
