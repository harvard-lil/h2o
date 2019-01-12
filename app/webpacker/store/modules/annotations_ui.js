import Vue from 'vue/dist/vue.esm';

const state = {
  all: (window.STATE_BOOTSTRAP
        ? window.STATE_BOOTSTRAP.annotations || []
        : []).map(a => ({id: a.id,
                        kind: a.kind,
                        expanded: a.kind == "note"}))
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
