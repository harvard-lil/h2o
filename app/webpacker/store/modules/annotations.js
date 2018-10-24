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
  destroy({ commit }, annotation) {
    Axios
      .delete(helpers.path(annotation))
      .then(resp => {
        // commit('destroy', annotation);
        window.location.reload();
      });
  }
};

const mutations = {
  destroy(state, annotation) {
    state.all.splice(state.all.indexOf(annotation), 1);
  }
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
};
