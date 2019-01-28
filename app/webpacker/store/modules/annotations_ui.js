import Vue from 'vue/dist/vue.esm';

const COLLAPSIBLE_KINDS = ["elide", "replace"];

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
    state.all.filter(obj => Math.max(5, Math.abs(obj.headY - headY)) == 5),

  collapsible: (state, getters) =>
    getters.getByKind(COLLAPSIBLE_KINDS),

  areAllExpanded: (state, getters) =>
    getters.collapsible.reduce((allExpanded, s) => allExpanded && s.expanded, true)
};

const actions = {
  toggleAllExpansions: ({commit, getters }) => {
    let newVals = {expanded: !getters.areAllExpanded};
    getters.collapsible.forEach(annotation => {
      commit("update", {obj: annotation, vals: newVals});
    });
  }
};

const mutations = {
  append: (state, payload) =>
    state.all.push(...payload),

  update: (state, payload) =>
    Object.assign(payload.obj, payload.vals),

  destroy: (state, payload) =>
    state.all.splice(state.all.indexOf(payload), 1),

  toggleExpansion: (state, payload) =>
    Vue.set(payload, 'expanded', !payload.expanded),

  expandById: (state, payload) =>
    payload
    .map(id => getters.getById(state)(id))
    .filter(obj => COLLAPSIBLE_KINDS.includes(obj.kind))
    .forEach(obj => Vue.set(obj, 'expanded', true))
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
};
