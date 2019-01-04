import Axios from '../../config/axios';

const helpers = {
  path(annotation) {
    return `/resources/${annotation.resource_id}/annotations/${annotation.id}`;
  }
};

const state = {
  all: window.STATE_BOOTSTRAP ? window.STATE_BOOTSTRAP.annotations || [] : []
};

const getters = {
  getById: (state) => (id) => {
    return state.all.find(obj => obj.id === id);
  },
  // Return annotations which either start, end, or bridge
  // the specified section (aka "paragraph")
  getBySectionIndex: (state) => (index) => {
    return state.all.filter(obj => (obj.start_paragraph == index ||
                                   obj.end_paragraph == index ||
                                   (obj.start_paragraph < index && obj.end_paragraph > index)));
  }
};

const actions = {
  update({ commit }, payload) {
    Axios
      .patch(helpers.path(payload.obj), {annotation: payload.vals})
      .then(resp => {
        commit('update', payload);
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
