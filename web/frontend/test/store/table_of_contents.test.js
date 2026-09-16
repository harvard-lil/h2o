import { reactive } from 'vue';
import toc from 'store/modules/table_of_contents';

describe('outline deletion', () => {
  it.each([2, 3, 4])('removes child %s without leaving holes or breaking getters', (id) => {
    const state = reactive({
      toc: {1: {id: 1, children: [2, 3, 4].map(id => ({
        id, children: [], resource_type: 'Temp', collapsed: true
      }))}},
      augments: {[id]: {collapsed: true}}
    });
    toc.mutations.delete(state, {casebook: 1, id});
    const remaining = [2, 3, 4].filter(value => value !== id);
    expect(state.toc[1].children.map(node => node.id)).toEqual(remaining);
    expect(toc.getters.topLevelNodes(state)(1)).toEqual(remaining);
    expect(toc.getters.auditTargets(state)(1)).toEqual(remaining);
    expect(toc.getters.collapsedNodes(state)(1)).toEqual(remaining);
    expect(state.augments).toEqual({});
  });

  it('removes a nested section and its descendant augments, preserving siblings', () => {
    const state = reactive({
      toc: {1: {id: 1, children: [{id: 2, children: [
        {id: 3, children: [{id: 4, children: []}]},
        {id: 5, children: []}
      ]}]}},
      augments: {3: {collapsed: true}, 4: {audit: true}, 5: {collapsed: false}}
    });
    toc.mutations.delete(state, {casebook: 1, id: 3});
    expect(state.toc[1].children[0].children).toEqual([{id: 5, children: []}]);
    expect(state.augments).toEqual({5: {collapsed: false}});
    expect(toc.getters.getNode(state)(4)).toBeUndefined();
    expect(toc.getters.openNodes(state)(1)).toEqual([1, 2, 5]);
  });
});
