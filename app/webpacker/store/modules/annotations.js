import Axios from '../../config/axios';

const helpers = {
  resourcePath: annotation => `/resources/${annotation.resource_id}/annotations`,
  path: annotation => `${helpers.resourcePath(annotation)}/${annotation.id}`
};

const state = {
  all: []
};

const getters = {
  getById: (state) => (id) =>
    state.all.find(
      obj => obj.id === id
    ),

  getBySectionIndex: (state) => (index) =>
    state.all.filter(
      obj => (obj.start_paragraph == index ||
             obj.end_paragraph == index ||
             (obj.start_paragraph < index && obj.end_paragraph > index))
    )
};

const actions = {
  list({ commit }, payload) {
    Axios
      .get(helpers.resourcePath(payload))
      .then(resp => {
        commit('append', resp.data);
      });
  },
  create({ commit }, payload) {
    Axios
      .post(helpers.resourcePath(payload),
            {annotation: payload})
      .then(resp => {
        commit('append', [{...payload, ...resp.data}]);
      });
  },
  update({ commit }, payload) {
    Axios
      .patch(helpers.path(payload.obj),
             {annotation: payload.vals})
      .then(resp => {
        commit('update', payload);
      });
  },
  destroy({ commit }, payload) {
    Axios
      .delete(helpers.path(payload))
      .then(resp => {
        commit('destroy', payload);
      });
  }
};

const mutations = {
  append(state, payload) {
    state.all.push(...payload);
  },
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
