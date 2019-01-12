import Vue from 'vue/dist/vue.esm';

const state = {
  all: []
};

const getters = {
  getById: (state) => (id) => {
    return state.all.find(obj => obj.id === id);
  },
  getByKind: (state) => (kinds) => {
    return state.all.filter(obj => kinds.includes(obj.kind));
  }
};

const mutations = {
  append(state, payload) {
    state.all.push(...payload);
  },
  toggleExpansion(state, payload) {
    Vue.set(payload, 'expanded', !payload.expanded);
  },
  toggleAllExpansions(state, payload) {
    getters.getByKind(state)(["elide", "replace"]).forEach(annotation => {
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
