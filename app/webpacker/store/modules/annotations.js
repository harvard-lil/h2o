import Axios from '../../config/axios';

const helpers = {
  path(annotation) {
    return '/resources/$RESOURCE_ID/annotations/$ANNOTATION_ID'.replace('$RESOURCE_ID', annotation.resource_id).replace('$ANNOTATION_ID', annotation.id);
  }
};

const state = {
  all: window.STATE_BOOTSTRAP ? window.STATE_BOOTSTRAP.annotations || [] : []
};

const getters = {
  getById: (state) => (id) => {
    return state.all.find(obj => obj.id === id);
  }
};

const actions = {
  update({ commit }, payload) {
    Axios
      .patch(helpers.path(payload.obj), {annotation: payload.vals})
      .then(resp => {
        commit('update', payload);
        window.location.reload();
      });
  },
  destroy({ commit }, payload) {
    Axios
      .delete(helpers.path(payload))
      .then(resp => {
        // commit('destroy', payload);
        window.location.reload();
      });
  }
};

const mutations = {
  update(state, payload) {
    Object.assign(payload.obj, payload.vals);
  },
  destroy(state, payload) {
    state.all.splice(state.all.indexOf(payload), 1);
  }
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
};
