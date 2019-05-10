import { parseHTML } from '../test_helpers';

import { mount } from '@vue/test-utils';
import TheAnnotator from 'components/TheAnnotator';

describe('TheAnnotator', () => {

  describe('contributesToOffsets', () => {
    test('returns false when node has the data-exclude-from-offset-calcs property', () => {
      const wrapper = mount(TheAnnotator);
      const node = parseHTML('<div data-exclude-from-offset-calcs="true">foo</div>');
      expect(wrapper.vm.contributesToOffsets(node)).toBe(false);
    });

    test('returns false when node is the child of an element having the data-exclude-from-offset-calcs property', () => {
      const wrapper = mount(TheAnnotator);
      const node = parseHTML('<div data-exclude-from-offset-calcs="true">foo</div>').childNodes[0];
      expect(wrapper.vm.contributesToOffsets(node)).toBe(false);
    });

    test('returns true when node does not have the data-exclude-from-offset-calcs property', () => {
      const wrapper = mount(TheAnnotator);
      const node = parseHTML('<div>foo</div>');
      expect(wrapper.vm.contributesToOffsets(node)).toBe(true);
    });
  });

});
