import Vue from 'vue';

const COLLAPSIBLE_KINDS = ["elide", "replace"];
export const Y_FIDELITY = 5;

const state = {
  all: []
};

const getters = {
  getById: state => id =>
    state.all.find(obj => obj.id === id),

  getByKind: (state, getters, rootState, rootGetters) => kinds =>
    state.all.filter(
      obj =>
        kinds.includes((rootGetters["annotations/getById"](obj.id) || {}).kind)
    ),

  getByHeadY: state => headY =>
    // round this to the nearest 5 pixels because browsers
    // sometimes report different fractional pixels for
    // elements on the same line. We've picked "5" out of an
    // abundance of caution.
    state.all.filter(obj => Math.max(Y_FIDELITY, Math.abs(obj.headY - headY)) == Y_FIDELITY),

  collapsible: (state, getters) =>
    getters.getByKind(COLLAPSIBLE_KINDS),

  areAllExpanded: (state, getters) =>
    getters.collapsible.reduce((allExpanded, s) => allExpanded && s.expanded, true)
};

const actions = {
  toggleExpansion: ({ commit, getters, rootGetters }, payload) => {
    commit("update", {obj: payload, vals: {expanded: !payload.expanded}});

    // Set headY=null for any annotations that come after this one
    // in order to trigger a recalculation of their headY value and potential
    // rerender of where their edit handle should be placed
    let annotation = rootGetters["annotations/getById"](payload.id);
    rootGetters["annotations/getStartingAtOrAfter"](annotation.start_offset)
      .forEach(a => commit("update", {obj: getters.getById(a.id),
                                     vals: {headY: null}}));
  },

  toggleAllExpansions: ({ dispatch, getters }) =>
    getters
    .collapsible
    .filter(s => s.expanded == getters.areAllExpanded)
    .forEach(s => dispatch("toggleExpansion", s)),

  expandById: ({ dispatch, getters }, payload) =>
    getters
    .collapsible
    .filter(s => payload.includes(s.id))
    .forEach(s => dispatch("toggleExpansion", s))
};

const mutations = {
  append: (state, payload) =>
    state.all.push(...payload),

  update: (state, payload) =>
    Object.assign(payload.obj, payload.vals),

  destroy: (state, payload) =>
    state.all.splice(state.all.indexOf(payload), 1),

  toggleExpansion: (state, payload) =>
    Vue.set(payload, 'expanded', !payload.expanded)
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
};
