import Axios from '../../config/axios';

const helpers = {
  resourcePath: annotation => `/resources/${annotation.resource_id}/annotations`,
  path: annotation => `${helpers.resourcePath(annotation)}/${annotation.id}`
};

const state = {
  all: window.STATE_BOOTSTRAP ? window.STATE_BOOTSTRAP.annotations || [] : []
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
    ),

  getBySectionIndexFullSpan: (state) => (index, start, end) =>
    getters.getBySectionIndex(state)(index).filter(
      obj => 
        (obj.start_paragraph < index || obj.start_offset <= start) &&
        (obj.end_paragraph > index || obj.end_offset >= end)
    ),

  getBySectionIndexPartialSpan: (state) => (index, start, end) =>
    getters.getBySectionIndex(state)(index).filter(
      obj =>
        (obj.start_paragraph == index &&
         obj.start_offset > start &&
         obj.start_offset < end) ||
        (obj.end_paragraph == index &&
         obj.end_offset > start &&
         obj.end_offset < end)
    )
};

const actions = {
  create({ commit }, payload) {
    Axios
      .post(helpers.resourcePath(payload),
            {annotation: payload})
      .then(resp => {
        commit('create', {...payload, ...resp.data});
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
  create(state, payload) {
    state.all.push(payload);
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
