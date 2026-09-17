import { VerificationCancelledError } from '../../libs/requestErrors';
import { mount, flushPromises } from '@vue/test-utils';
import { cloneDeep } from 'lodash';
import Vuex from 'vuex/dist/vuex.esm-bundler.js';
import annotations from 'store/modules/annotations';
import annotations_ui from 'store/modules/annotations_ui';
import resources_ui from 'store/modules/resources_ui';
import NoteAnnotation from 'components/NoteAnnotation';

describe('new note focus', () => {
  it.each([true, false])('only focuses the rendered head editor (isHead=%s)', async (isHead) => {
    const store = new Vuex.Store(cloneDeep({modules: {
      annotations, annotations_ui, resources_ui
    }}));
    const wrapper = mount(NoteAnnotation, {
      attachTo: document.body,
      global: {plugins: [store]},
      props: {
        annotation: {id: -1, kind: 'note', content: '', start_offset: 0, end_offset: 10},
        startOffset: 0, endOffset: 10, isHead
      }
    });
    try {
      await flushPromises();
      expect(wrapper.find('textarea').exists()).toBe(isHead);
      if (isHead) {
        expect(document.activeElement).toBe(wrapper.get('textarea').element);
      }
    } finally {
      wrapper.unmount();
    }
  });
});

describe('note saves', () => {
  it.each([new Error('Request failed'), new VerificationCancelledError()])('keeps an existing note editor open after %s', async (error) => {
    const store = new Vuex.Store(cloneDeep({modules: {
      annotations, annotations_ui, resources_ui
    }}));
    const wrapper = mount(NoteAnnotation, {
      global: {plugins: [store]},
      props: {
        annotation: {id: 1, kind: 'note', content: 'original', start_offset: 0, end_offset: 10},
        startOffset: 0, endOffset: 10, isHead: true
      }
    });
    let rejectSave;
    wrapper.vm.update = () => new Promise((resolve, reject) => { rejectSave = reject; });
    wrapper.vm.editNote();
    await wrapper.vm.$nextTick();
    await wrapper.get('textarea').setValue('keep this text');
    const pending = wrapper.vm.submit('note', 'keep this text');
    const checked = error instanceof VerificationCancelledError ? expect(pending).resolves.toBeUndefined() : expect(pending).rejects.toThrow('Request failed');
    expect(wrapper.vm.saving).toBe(true);
    wrapper.vm.dismissNote();
    expect(wrapper.vm.isEditing).toBe(true);
    rejectSave(error);
    await checked;
    expect(wrapper.vm.saving).toBe(false);
    expect(wrapper.vm.isEditing).toBe(true);
    expect(wrapper.get('textarea').element.value).toBe('keep this text');
    wrapper.unmount();
  });
});
