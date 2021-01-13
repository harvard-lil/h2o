import util from 'util';

import { parseHTML,
         removeVueScopedCSSAttributes } from '../test_helpers';

import { cloneDeep } from 'lodash';

import { mount,
         createLocalVue } from '@vue/test-utils';

import Vuex from 'vuex';
import annotations from "store/modules/annotations";
import annotations_ui from "store/modules/annotations_ui";
import footnotes_ui from "store/modules/footnotes_ui";
import resources_ui from "store/modules/resources_ui";

import TheResourceBody from 'components/TheResourceBody';

const localVue = createLocalVue();
localVue.use(Vuex);

const DEFAULT_ANNOTATION = Object.freeze({
  "id": 1,
  "resource_id": 1,
  "start_offset": 0,
  "end_offset": Number.MAX_SAFE_INTEGER,
  "kind": "highlight",
  "content": null
});

describe('TheResourceBody', () => {
  let store;

  beforeEach(() => {
    store = new Vuex.Store(cloneDeep({
      modules: {annotations,
                annotations_ui,
                footnotes_ui,
                resources_ui}
    }));
  });

  [['renders multiple annotations',
    '<div>%s %s %s</div>', ['foo', 'bar', 'buzz'],
    [{...DEFAULT_ANNOTATION, start_offset: 0, end_offset: 3},
     {...DEFAULT_ANNOTATION, start_offset: 4, end_offset: 7},
     {...DEFAULT_ANNOTATION, start_offset: 8, end_offset: 12}]],

   ['wraps text in an annotation when the annotation entirely spans the text',
    '<div>%s</div>', ['foo bar'],
    [cloneDeep(DEFAULT_ANNOTATION)]],

   ['wraps inline elements in an annotation when the annotation entirely spans the elements',
    '<div>%s</div>', ['<em>foo</em> <span>bar</span>'],
    [cloneDeep(DEFAULT_ANNOTATION)]],

   ['wraps innerHTML of a block level element rather than wrapping the block element itself',
    '<div><h1>%s</h1></div>', ['foo bar'],
    [cloneDeep(DEFAULT_ANNOTATION)]],

   ['splits text when an annotation starts midway through the text',
    '<div>f%s</div>', ['oo bar'],
    [{...DEFAULT_ANNOTATION, start_offset: 1}]],

   ['splits text when an annotation ends midway through the text',
    '<div>%soo bar</div>', ['f'],
    [{...DEFAULT_ANNOTATION, end_offset: 1}]],

   ['splits text when an annotation begins and ends midway through the text',
    '<div>f%sr</div>', ['oo ba'],
    [{...DEFAULT_ANNOTATION, start_offset: 1, end_offset: 6}]],

   ['splits an annotation into chunks when beginning within an element and ending outside of it',
    '<div><em>f%s</em><span>%sr</span></div>', ['oo', 'ba'],
    [{...DEFAULT_ANNOTATION, start_offset: 1, end_offset: 5}]],

   ['preserves whitespace at beginning of annotated text',
    '<div>%s</div>', [' foo'],
    [cloneDeep(DEFAULT_ANNOTATION)]],

   ['preserves whitespace at end of annotated text',
    '<div>%s</div>', ['foo '],
    [cloneDeep(DEFAULT_ANNOTATION)]]

  ].forEach(([title, html, selection, annotations]) => {
    it(title, () => {
      store.commit('annotations/append', annotations);
      const wrapper = mount(TheResourceBody, {store, localVue, propsData: {
        resource: {content: util.format(html, ...selection)}
      }});
      expect(wrapper.findAll(`.selected-text`).wrappers.map(w => removeVueScopedCSSAttributes(parseHTML(w.html())).innerHTML)).toEqual(selection);
    });
  });

  [['preserves whitespace when an annotation contains only a space',
    '<div>foo bar</div>',
    [{...DEFAULT_ANNOTATION, start_offset: 3, end_offset: 4}]],

   ['preserves whitespace when an annotation ends in a space',
    '<div><span>foo</span> bar</div>',
    [{...DEFAULT_ANNOTATION, start_offset: 0, end_offset: 4}]],

   ['preserves whitespace when an annotation contains only a newline and whitespace',
    '<div>\n     </div>',
    [{...DEFAULT_ANNOTATION, start_offset: 0, end_offset: 6}]],

   ['preserves whitespace separating block and inline tags',
    '<div>\n   <span>foo</span> bar</div>',
    [{...DEFAULT_ANNOTATION, start_offset: 0, end_offset: 11}]],

   ['preserves whitespace separating block-level tags',
    '<div>\n   <p>foo</p> bar</div>',
    [{...DEFAULT_ANNOTATION, start_offset: 0, end_offset: 11}]],

   ['preserves whitespace separating span-level tags',
    '<span>\n   <span>foo</span> bar</span>',
    [{...DEFAULT_ANNOTATION, start_offset: 0, end_offset: 11}]],

   ['preserves whitespace between tags',
    '<div><p>fizz</p>\n                <p>foo bar, <span>(a)</span>\n                  <span>(2)</span>\n                </p>\n                <p>buzz</p></div>',
    [{...DEFAULT_ANNOTATION, start_offset: 31, end_offset: 54}]]

  ].forEach(([title, html, annotations]) => {
    it(title, () => {
      store.commit('annotations/append', annotations);
      const wrapper = mount(TheResourceBody, {store, localVue, propsData: {resource: {content: html}}});
      expect(parseHTML(wrapper.html()).textContent).toEqual(parseHTML(html).textContent);
    });
  });

  it('when rendering, orders annotations first by length (longer wraps shorter)');
  it('when rendering, orders annotations second by time (newer wraps older)');
});
