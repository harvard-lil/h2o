import Vue from 'vue/dist/vue.esm';

const COLLAPSIBLE_KINDS = ["elide", "replace"];

const state = {
  all: []
};

const getters = {
  getById: state => id =>
    state.all.find(obj => obj.id === id),

  getByKind: state => kinds =>
    state.all.filter(obj => kinds.includes(obj.kind)),

  getByHeadY: state => headY =>
    // round this to the nearest 5 pixels because browsers
    // sometimes report different fractional pixels for
    // elements on the same line. We've picked "5" out of an
    // abundance of caution.
    state.all.filter(obj => Math.max(5, Math.abs(obj.headY - headY)) == 5),

  getCollapsible: state =>
    getters.getByKind(state)(COLLAPSIBLE_KINDS),

  areAllExpanded: state =>
    getters.getCollapsible(state).reduce((allExpanded, s) => allExpanded && s.expanded, true)
};

const mutations = {
  append: (state, payload) =>
    state.all.push(...payload),

  destroy: (state, payload) =>
    state.all.splice(state.all.indexOf(payload), 1),

  toggleExpansion: (state, payload) =>
    Vue.set(payload, 'expanded', !payload.expanded),

  toggleAllExpansions: (state, payload) =>
    getters.getCollapsible(state).forEach(annotation => {
      Vue.set(annotation, 'expanded', payload);
    }),

  expandById: (state, payload) =>
    payload
    .map(id => getters.getById(state)(id))
    .filter(obj => COLLAPSIBLE_KINDS.includes(obj.kind))
    .forEach(obj => Vue.set(obj, 'expanded', true)),
};

export default {
  namespaced: true,
  state,
  getters,
  mutations
};
