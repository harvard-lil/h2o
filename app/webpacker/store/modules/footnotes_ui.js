import Vue from 'vue/dist/vue.esm';

const state = {
  all: {}
};

const getters = {
  getById: state => id =>
    state.all[id]
};

const mutations = {
  register: (state, payload) => {
    let footnoteState = state.all[state.id];
    if(footnoteState) {
      footnoteState.push(...payload.annotationIds.filter(id => !footnoteState.includes(id)));
    } else {
      Vue.set(state.all, payload.id, payload.annotationIds);
    }
  }
};

export default {
  namespaced: true,
  state,
  getters,
  mutations
};
