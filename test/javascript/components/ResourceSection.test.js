import { parseNode } from '../test_helpers';
import { mount,
         createLocalVue } from '@vue/test-utils';

import Vuex from 'vuex';
import annotations from "store/modules/annotations";
import annotations_ui from "store/modules/annotations_ui";
import footnotes_ui from "store/modules/footnotes_ui";
import resources_ui from "store/modules/resources_ui";

import ResourceSection from 'components/ResourceSection';

const localVue = createLocalVue();
localVue.use(Vuex);

describe('ResourceSection', () => {
  let store;

  beforeEach(() => {
    store = new Vuex.Store({
      modules: {annotations,
                annotations_ui,
                footnotes_ui,
                resources_ui}
    });
  });

  test('correctly places an annotation', () => {
    const annotation = {
      "id": 352630,
      "resource_id": 63432,
      "start_paragraph": 0,
      "end_paragraph": 0,
      "start_offset": 1,
      "end_offset": 5,
      "kind": "link",
      "content": "http://google.com/",
      "created_at": "2019-02-11T19:16:03.604Z",
      "updated_at": "2019-02-11T19:16:03.604Z"
    };

    store.commit('annotations/append', [annotation]);

    const wrapper = mount(ResourceSection, {store, localVue, propsData: {
      index: 0,
      el: parseNode('<div>Hello world</div>')
    }});

    expect(wrapper.find(`a[href="${annotation.content}"]`).text()).toEqual('ello');
  });
});
