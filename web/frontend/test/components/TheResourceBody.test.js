import util from 'util';

import { parseHTML,
         removeVueScopedCSSAttributes } from '../test_helpers';

import { cloneDeep } from 'lodash';

import { mount, flushPromises } from '@vue/test-utils';

// Use Vuex's ESM build so store mutations share Vue's test-runtime reactivity.
import Vuex from 'vuex/dist/vuex.esm-bundler.js';
import annotations from "store/modules/annotations";
import annotations_ui from "store/modules/annotations_ui";
import footnotes_ui from "store/modules/footnotes_ui";
import resources_ui from "store/modules/resources_ui";

import TheResourceBody from 'components/TheResourceBody';
import TheResource from 'components/TheResource';
import Axios from '../../config/axios';


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

  it.each([true, false])('loads saved annotations without a page header (editable=%s)', async (editable) => {
    const get = vi.spyOn(Axios, 'get').mockResolvedValue({data: [
      {...DEFAULT_ANNOTATION, resource_id: 42, end_offset: 3}
    ]});
    expect(document.querySelector('header.casebook')).toBeNull();
    const wrapper = mount(TheResource, {
      global: {plugins: [store]},
      props: {resourceId: 42, resource: {content: '<p>foo bar</p>'}, editable}
    });
    try {
      await flushPromises();
      expect(get).toHaveBeenCalledExactlyOnceWith('/resources/42/annotations');
      expect(wrapper.find('.highlight .selected-text').text()).toBe('foo');
    } finally {
      wrapper.unmount();
      get.mockRestore();
    }
  });

  it('does not fetch casebook annotations for a standalone legal document', async () => {
    const get = vi.spyOn(Axios, 'get');
    const wrapper = mount(TheResource, {
      global: {plugins: [store]},
      props: {resource: {id: 42, content: '<p>foo bar</p>'}, editable: false}
    });
    try {
      await flushPromises();
      expect(get).not.toHaveBeenCalled();
      expect(wrapper.text()).toContain('foo bar');
    } finally {
      wrapper.unmount();
      get.mockRestore();
    }
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
      const wrapper = mount(TheResourceBody, {global: { plugins: [store] }, props: {
        resource: {content: util.format(html, ...selection)}
      }});
      expect(wrapper.findAll(`.selected-text`).map(w => removeVueScopedCSSAttributes(parseHTML(w.html({ raw: true }))).innerHTML)).toEqual(selection);
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
      const wrapper = mount(TheResourceBody, {global: { plugins: [store] }, props: {resource: {content: html}}});
      expect(parseHTML(wrapper.html({ raw: true })).textContent).toEqual(parseHTML(html).textContent);
    });
  });

  it('renders one expansion toggle for an elision spanning paragraphs after rerender', async () => {
    store.commit('annotations/append', [{...DEFAULT_ANNOTATION, kind: 'elide', start_offset: 1, end_offset: 5}]);
    const wrapper = mount(TheResourceBody, {global: {plugins: [store]}, props: {
      resource: {content: '<p>foo</p><p>bar</p>'}
    }});
    expect(wrapper.findAll('.toggle')).toHaveLength(1);
    expect(wrapper.findAll('.selected-text').map(w => w.text())).toEqual(['oo', 'ba']);
    wrapper.vm.$forceUpdate();
    await wrapper.vm.$nextTick();
    expect(wrapper.findAll('.toggle')).toHaveLength(1);
    expect(store.state.annotations.all[0]).not.toHaveProperty('used');
    wrapper.unmount();
  });

  describe.each(['elide', 'replace'])('%s paragraph layout', (kind) => {
    it.each([
      '<p>foo</p><p>bar</p>',
      '<blockquote><p><em>foo</em></p></blockquote><p>bar</p>',
      '<blockquote> <p>foo</p> </blockquote><p>bar</p>',
    ])('marks fully covered elements, including nested wrappers: %s', async (content) => {
      const start = content.startsWith('<blockquote> ') ? 1 : 0;
      store.commit('annotations/append', [{...DEFAULT_ANNOTATION, kind,
        content: 'replacement', start_offset: start, end_offset: start + 3}]);
      const wrapper = mount(TheResourceBody, {global: {plugins: [store]}, props: {
        resource: {content}
      }});
      try {
        expect(wrapper.find('p').classes()).toContain('fully-elided');
        expect(wrapper.findAll('p')[1].classes()).not.toContain('fully-elided');
        if (wrapper.find('blockquote').exists()) {
          expect(wrapper.find('blockquote').classes()).toContain('fully-elided');
        }
        await wrapper.find('.toggle').trigger('click');
        expect(wrapper.find('.selected-text').isVisible()).toBe(true);
        expect(wrapper.find('p').classes()).toContain('fully-elided');
      } finally {
        wrapper.unmount();
      }
    });
  });

  it.each([['elide', 2], ['replace', 2], ['highlight', 3]])(
    'keeps ordinary paragraph layout for %s ending at offset %s', (kind, end_offset) => {
      store.commit('annotations/append', [{...DEFAULT_ANNOTATION, kind, end_offset, content: 'replacement'}]);
      const wrapper = mount(TheResourceBody, {global: {plugins: [store]}, props: {
        resource: {content: '<p>foo</p>'}
      }});
      try {
        expect(wrapper.find('p').classes()).not.toContain('fully-elided');
      } finally {
        wrapper.unmount();
      }
    }
  );

  it('preserves elision state and unselected text through saves and subsequent annotations', async () => {
    let finishSave;
    const post = vi.spyOn(Axios, 'post').mockImplementation(() => new Promise(resolve => { finishSave = resolve; }));
    const wrapper = mount(TheResource, {
      global: { plugins: [store], directives: {selectionchange: {}} },
      props: { resource: {content: '<p>before selected after</p><p>another paragraph</p>'}, editable: true }
    });
    store.commit('annotations/append', [{...DEFAULT_ANNOTATION, id: -1, kind: 'elide', start_offset: 7, end_offset: 15}]);
    await flushPromises();
    expect(wrapper.find('.case-text').exists()).toBe(true);
    expect(wrapper.find('.selected-text').text()).toBe('selected');
    expect(wrapper.find('.case-text').text()).toContain('before');
    expect(wrapper.find('.case-text').text()).toContain('another paragraph');
    expect(post).toHaveBeenCalledTimes(1);
    finishSave({data: {id: 2}});
    await flushPromises();
    expect(wrapper.find('.selected-text').text()).toBe('selected');
    expect(store.state.annotations.all[0].id).toBe(2);
    expect(wrapper.find('button').text()).toBe('Show elided text');
    store.commit('annotations/append', [{...DEFAULT_ANNOTATION, id: -2, kind: 'elide', start_offset: 21, end_offset: 28}]);
    await flushPromises();
    expect(post).toHaveBeenCalledTimes(2);
    expect(wrapper.findAll('.selected-text').map(w => w.text())).toEqual(['selected', 'another']);
    expect(wrapper.find('.case-text').text()).toContain('before');
    finishSave({data: {id: 3}});
    await flushPromises();
    expect(store.state.annotations.all.map(a => a.id)).toEqual([2, 3]);
    await wrapper.find('button').trigger('click');
    expect(wrapper.findAll('.selected-text').every(w => w.isVisible())).toBe(true);
    wrapper.unmount();
    post.mockRestore();
  });

  it('when rendering, orders annotations first by length (longer wraps shorter)');
  it('when rendering, orders annotations second by time (newer wraps older)');
});
