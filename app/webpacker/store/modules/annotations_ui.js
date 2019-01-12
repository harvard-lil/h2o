import Vue from 'vue/dist/vue.esm';

const state = {
  all: (window.STATE_BOOTSTRAP
        ? window.STATE_BOOTSTRAP.annotations || []
        : []).map(a => ({id: a.id, expanded: a.kind == "note"}))
};

const getters = {
  getById: (state) => (id) => {
    return state.all.find(obj => obj.id === id);
  }
};

const mutations = {
  toggleExpansion(state, payload) {
    Vue.set(payload, 'expanded', !payload.expanded);
  },
  toggleAllExpansions(state, payload) {
    state.all.forEach(annotation => {
      Vue.set(annotation, 'expanded', payload);
    });
  }
};

export default {
  namespaced: true,
  state,
  getters,
  mutations
};
