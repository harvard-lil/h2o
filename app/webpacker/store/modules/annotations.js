import Axios from '../../config/axios';

const helpers = {
  resourcePath: annotation => `/resources/${annotation.resource_id}/annotations`,
  path: annotation => `${helpers.resourcePath(annotation)}/${annotation.id}`
};

const state = {
  all: []
};

const getters = {
  getCount: state => state.all.length,

  getById: state => id =>
    state.all.find(
      obj => obj.id === id
    ),

  getInSectionStartingAtOrAfter: state => (offset) =>
    state.all.filter(
      obj => obj.start_offset >= offset
    ),

  // Annotations that entirely span (or exceed) the provided offsets.
  // Used when inserting annotations at breakpoints
  getSpanningOffsets: state => (start, end) =>
    state.all.filter(
      obj => obj.start_offset <= start && obj.end_offset >= end
    ),

   // Annotations whose start or end points fall WITHIN
  // (i.e. not on the edges) the start and end bounds.
  // Used for finding where to split Text nodes.
  getWithinOffsets: state => (start, end) =>
    state.all.filter(
      obj => obj.start_offset > start || obj.end_offset < end
    ),
};

const actions = {

  list: ({ commit }, payload) =>
    Axios
      .get(helpers.resourcePath(payload))
      .then(resp => {
        commit('append', resp.data);
      }),

  create: ({ commit }, payload) =>
    Axios
      .post(helpers.resourcePath(payload),
            {annotation: payload})
      .then(resp => {
        commit('append', [{...payload, ...resp.data}]);
      }),

  update: ({ commit }, payload) =>
    Axios
      .patch(helpers.path(payload.obj),
             {annotation: payload.vals})
      .then(resp => {
        commit('update', {obj: payload.obj,
                          vals: {...payload.vals,
                                 ...resp.data}});
      }),

  destroy: ({ commit, rootGetters }, payload) =>
    Axios
      .delete(helpers.path(payload))
      .then(resp => {
        commit('destroy', payload);
        commit('annotations_ui/destroy',
               rootGetters['annotations_ui/getById'](payload.id),
               {root: true});
      }),

  createAndUpdate: ({ commit, rootGetters }, payload) =>
    Axios
      .post(helpers.resourcePath(payload.obj),
            {annotation: {...payload.obj,
                          ...payload.vals}})
      .then(resp => {
        // In the case where we have a placeholder annotation on the page
        // with a null id, update that id here so that we continue to track
        // the state using the same ui state object
        commit('annotations_ui/update',
               {obj: rootGetters['annotations_ui/getById'](payload.obj.id),
                vals: {id: resp.data.id}},
               {root: true});
        commit('update', {obj: payload.obj,
                          vals: {...payload.vals,
                                 ...resp.data}});
      })
};

const mutations = {
  append: (state, payload) =>
    state.all.push(...payload),

  update: (state, payload) =>
    Object.assign(payload.obj, payload.vals),

  destroy: (state, payload) =>
    state.all.splice(state.all.indexOf(payload), 1)
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
};
