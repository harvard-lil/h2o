import { mount, flushPromises } from '@vue/test-utils';
import Vuex from 'vuex';
import QuickAdd from '../../components/QuickAdd.vue';

describe('quick-add submission failures', () => {
  let wrapper, merge;
  beforeEach(async () => {
    merge = vi.fn();
    const store = new Vuex.Store({modules: {
      globals: {namespaced: true, getters: {casebook: () => () => 123, section: () => () => 456}},
      case_search: {namespaced: true, getters: {getSources: () => []}},
      table_of_contents: {namespaced: true, actions: {slowMerge: merge}},
    }});
    wrapper = mount(QuickAdd, {global: {plugins: [store], stubs: {ResultsForm: true, AdvancedSearch: true}}});
    await wrapper.find('input[type="text"]').setValue('Example section');
  });
  afterEach(() => { wrapper.unmount(); vi.unstubAllGlobals(); });

  it.each(['network', 'http', 'invalid-json', 'interrupted-body'])('preserves input and displays %s failures', async failure => {
    const fetch = vi.fn();
    vi.stubGlobal('fetch', fetch);
    if (failure === 'network') fetch.mockRejectedValue(new TypeError('Failed to fetch'));
    if (failure === 'http') fetch.mockResolvedValue({ok: false, status: 500});
    if (failure === 'invalid-json') fetch.mockResolvedValue({ok: true, json: () => Promise.reject(new SyntaxError('Invalid JSON'))});
    if (failure === 'interrupted-body') fetch.mockResolvedValue({ok: true, json: () => Promise.reject(new TypeError('Terminated'))});
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    expect(wrapper.find('.message').text()).toContain('Your entry has been kept');
    expect(wrapper.find('input[type="text"]').element.value).toBe('Example section');
    expect(merge).not.toHaveBeenCalled();

    fetch.mockResolvedValue({ok: true, json: async () => ({id: 123, children: []})});
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    expect(wrapper.find('.message').exists()).toBe(false);
    expect(wrapper.find('input[type="text"]').element.value).toBe('');
    expect(merge).toHaveBeenCalledOnce();
  });

  it('does not conceal unexpected programming errors', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new RangeError('Unexpected bug')));
    await expect(wrapper.vm.handleAdd()).rejects.toThrow('Unexpected bug');
  });
});
