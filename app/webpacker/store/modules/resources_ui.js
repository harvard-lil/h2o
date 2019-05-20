import Vue from 'vue/dist/vue.esm';

const state = {
  editable: false
};

const getters = {
  getEditability: state =>
    state.editable
};

const mutations = {
  setEditability: (state, payload) =>
    state.editable = payload
};

export default {
  namespaced: true,
  state,
  getters,
  mutations
};
