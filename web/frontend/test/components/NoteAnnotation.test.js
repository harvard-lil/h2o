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
