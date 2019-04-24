import util from 'util';

import { parseHTML } from '../test_helpers';
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

const DEFAULT_ANNOTATION = Object.freeze({
  "id": 1,
  "resource_id": 1,
  "start_paragraph": 0,
  "end_paragraph": Number.MAX_SAFE_INTEGER,
  "start_offset": 0,
  "end_offset": Number.MAX_SAFE_INTEGER,
  "kind": "highlight",
  "content": null
});

describe('ResourceSection', () => {
  let store;

  beforeEach(() => {
    store = new Vuex.Store({
      modules: {annotations,
                annotations_ui,
                footnotes_ui,
                resources_ui}
    });

    // Reset the store because right now cloneDeep isn't working
    store.state.annotations.all.map(a => store.commit('annotations/destroy', a));
  });

  test.each([
    ['wraps text in an annotation when the annotation entirely spans the text',
     '<div>%s</div>', ['foo bar'],
     [DEFAULT_ANNOTATION]],

    ['wraps inline elements in an annotation when the annotation entirely spans the elements',
     '<div>%s</div>', ['<em>foo</em> <span>bar</span>'],
     [DEFAULT_ANNOTATION]],
    
    ['wraps innerHTML of a block level element rather than wrapping the block element itself',
     '<div><h1>%s</h1></div>', ['foo bar'],
     [DEFAULT_ANNOTATION]],

    ['splits text when an annotation starts midway through the text',
     '<div>f%s</div>', ['oo bar'],
     [{...DEFAULT_ANNOTATION, start_paragraph: 1, start_offset: 1}]],

    ['splits text when an annotation ends midway through the text',
     '<div>%soo bar</div>', ['f'],
     [{...DEFAULT_ANNOTATION, end_paragraph: 1, end_offset: 1}]],

    ['splits text when an annotation begins and ends midway through the text',
     '<div>f%sr</div>', ['oo ba'],
     [{...DEFAULT_ANNOTATION, start_paragraph: 1, end_paragraph: 1, start_offset: 1, end_offset: 6}]],

    ['splits an annotation into chunks when beginning within an element and ending outside of it',
     '<div><em>f%s</em><span>%sr</span></div>', ['oo', 'ba'],
     [{...DEFAULT_ANNOTATION, start_paragraph: 1, end_paragraph: 1, start_offset: 1, end_offset: 5}]],

    ['preserves whitespace at beginning of annotated text',
     '<div>%s</div>', [' foo'],
     [DEFAULT_ANNOTATION]],

    ['preserves whitespace at end of annotated text',
     '<div>%s</div>', ['foo '],
     [DEFAULT_ANNOTATION]]

  ])('%s', (testTitle, sectionHTML, toSelect, annotations) => {
    store.commit('annotations/append', annotations);
    const wrapper = mount(ResourceSection, {store, localVue, propsData: {
      index: 1,
      el: parseHTML(util.format(sectionHTML, ...toSelect))
    }});
    expect(wrapper.findAll(`.selected-text`).wrappers.map(w => parseHTML(w.html()).innerHTML)).toEqual(toSelect);
  });

  test('preserves whitespace when annotation contains only whitespace', () => {
    store.commit('annotations/append', [{...DEFAULT_ANNOTATION, start_paragraph: 1, end_paragraph: 1, start_offset: 3, end_offset: 4}]);
    const wrapper = mount(ResourceSection, {store, localVue, propsData: {
      index: 1,
      el: parseHTML('<div>foo bar</div>')
    }});
    expect(parseHTML(wrapper.find(`.selected-text`).html()).textContent).toEqual(' ');
  });

  test.todo('when rendering, orders annotations first by length (longer wraps shorter)');
  test.todo('when rendering, orders annotations second by time (newer wraps older)');
});
