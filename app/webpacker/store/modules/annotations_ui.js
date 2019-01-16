import Vue from 'vue/dist/vue.esm';

const state = {
  all: []
};

const getters = {
  getById: state => id =>
    state.all.find(obj => obj.id === id),

  getByKind: state => kinds =>
    state.all.filter(obj => kinds.includes(obj.kind)),

  getByHeadY: state => headY =>
    state.all.filter(obj => obj.headY == headY)
};

const mutations = {
  append(state, payload) {
    state.all.push(...payload);
  },
  destroy(state, payload) {
    state.all.splice(state.all.indexOf(payload), 1);
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
