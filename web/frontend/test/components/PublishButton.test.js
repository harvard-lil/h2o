import { mount, flushPromises } from '@vue/test-utils';
import Vuex from 'vuex';
import Axios from '../../config/axios';
import PublishButton from '../../components/PublishButton.vue';

const Modal = {template: '<div><slot name="body" /><slot name="footer" /></div>'};

describe('publishing failures', () => {
  let wrapper, adapter, originalAdapter;
  beforeEach(async () => {
    originalAdapter = Axios.defaults.adapter;
    adapter = vi.fn();
    Axios.defaults.adapter = adapter;
    const store = new Vuex.Store({modules: {globals: {
      namespaced: true, getters: {casebook: () => () => 123},
    }}});
    wrapper = mount(PublishButton, {
      props: {publishCheck: {isVerifiedProfessor: true}},
      global: {plugins: [store], stubs: {Modal, 'font-awesome-icon': true}},
    });
    await wrapper.find('button.publish').trigger('click');
  });
  afterEach(() => { wrapper.unmount(); Axios.defaults.adapter = originalAdapter; });

  it.each([
    new Error('Network Error'),
    {response: {status: 400, data: {}}},
    {response: {status: 403, data: '<html>Forbidden</html>'}},
    {response: {status: 500, data: 'Server error'}},
  ])('shows a visible error and allows recovery for %j', async error => {
    adapter.mockRejectedValue(error);
    await wrapper.find('button.confirm').trigger('click');
    await flushPromises();
    expect(wrapper.find('[role="alert"]').text()).toContain('Publishing could not be confirmed');
    expect(wrapper.find('button.confirm').element.disabled).toBe(false);
    expect(wrapper.vm.publishSuccess).toBe(false);

    adapter.mockResolvedValue({status: 200, data: {url: '/casebooks/123/'}});
    await wrapper.find('button.confirm').trigger('click');
    await flushPromises();
    expect(wrapper.find('[role="alert"]').exists()).toBe(false);
    expect(wrapper.vm.publishSuccess).toBe(true);
    expect(wrapper.text()).toContain('/casebooks/123/');
  });

  it('prevents duplicate submissions while publishing', async () => {
    let finish;
    adapter.mockImplementation(() => new Promise(resolve => { finish = resolve; }));
    await wrapper.find('button.confirm').trigger('click');
    await flushPromises();
    expect(wrapper.find('button.confirm').element.disabled).toBe(true);
    wrapper.vm.confirmPublish();
    expect(adapter).toHaveBeenCalledTimes(1);
    finish({status: 200, data: {url: '/casebooks/123/'}});
    await flushPromises();
  });

  it('does not redirect on a malformed success response', async () => {
    adapter.mockResolvedValue({status: 200, data: '<html>Login</html>'});
    await wrapper.find('button.confirm').trigger('click');
    await flushPromises();
    expect(wrapper.find('[role="alert"]').exists()).toBe(true);
    expect(wrapper.vm.canonicalUrl).toBeNull();
  });
});
