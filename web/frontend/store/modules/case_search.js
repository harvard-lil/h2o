import Axios from '../../config/axios';
import Vue from 'vue';
import _ from 'lodash';
import url from '../../libs/urls';

const sourcesURL = url.url('search_sources')();

const searchUsingURL = url.url('search_using');

const state = {
  sources: [],
  searches: {}
};

const helpers = {
  normalize: function normalize(queryObj) {
    const string = _.keys(queryObj).map(k => `${k}=${queryObj[k]}`).join(",");
    return string;
  },
  encodeQuery: function encodeQuery(queryObj) {
    const string = _.keys(queryObj).map(k => `${k === 'query' ? 'q' : k }=${encodeURI(queryObj[k])}`).join("&");
    return string;
  }
};

const getters = {
  getSearch: state => queryObj => {
    const qKey = helpers.normalize(queryObj);
    return state.searches[qKey];
  },
  getSources: state => {
    return state.sources;
  }
};

const mutations = {
  setSources: (state, sources) => {
    let internalSources = sources.map((x,i) => ({ ...x, sourceIndex:i }));
    Vue.set(state, 'sources', internalSources);
  },
  overwrite: (state, {queryObj, source, results}) => {
    const qKey = helpers.normalize(queryObj);
    Vue.set(state.searches[qKey],source.sourceIndex, results);
  },
  setPending: (state, {queryObj, source}) => {
    const qKey = helpers.normalize(queryObj);
    Vue.set(state.searches[qKey], source.sourceIndex, 'pending');
  },
  setDisabled: (state, {queryObj, source}) => {
    const qKey = helpers.normalize(queryObj);
    Vue.set(state.searches[qKey], source.sourceIndex, 'disabled');
  },
  scrub: (state, {queryObj, source}) => {
    const qKey = helpers.normalize(queryObj);
    Vue.set(state.searches[qKey], source.sourceIndex, 'timeout');
  },
  initializeSearch: (state, queryObj) => {
    const qKey = helpers.normalize(queryObj);
    if (!_.has(state.searches, qKey)) {
      Vue.set(state.searches, qKey, state.sources.map(({enabled}) => enabled ? 'pending' : 'disabled'));
    }
  },
  toggleSourceEnabled: (state, sourceIndex) => {
    state.sources[sourceIndex].enabled = !state.sources[sourceIndex].enabled;
  }
};

const actions = {
  fetchForSource: ({state, commit, dispatch}, {queryObj, source}) => {
    commit('setPending', {queryObj, source});
    const searchUrlRoot = searchUsingURL({sourceId: source.id});
    const url = `${searchUrlRoot}?${helpers.encodeQuery(queryObj)}`;
    Axios.get(url)
      .then(resp => {
        let results = resp.data.results;
        results.forEach(x => x.source_id = source.id);
        commit('overwrite', {queryObj, source, results});
      }, console.error);
    dispatch('timeOutSearch', {queryObj, source});
  },
  fetchForAllSources: ({state, commit, dispatch}, queryObj) => {
    commit('initializeSearch', queryObj);
    for(let source of state.sources) {
      if (source.enabled) {
        dispatch('fetchForSource', {queryObj, source});
      } else {
        commit('setDisabled', {queryObj, source});
      }
    }
  },
  fetchSources: ({ state, commit, dispatch }) => {
    if (!state.sources || state.sources.length === 0) {
      Axios.get(sourcesURL).then( resp => {
        commit('setSources', resp.data.sources);
      });
    }
  },
  timeOutSearch: ({ state, commit }, {queryObj, source}) => {
    const searchTimeout = 30000;
    setTimeout(() => {
      if (state.searches[helpers.normalize(queryObj)][source.id] === 'pending') {
        commit('scrub', {queryObj, source});
      }
    }, searchTimeout);
  },
  toggleSource: ({ state, commit, dispatch }, {source_id, queryObj}) => {
    let source = _.find(state.sources, x => x.id === source_id);
    commit("toggleSourceEnabled", source.sourceIndex);
    if (source.enabled) {
      dispatch('fetchForSource', {queryObj, source});
    } else {
      commit('setDisabled', {queryObj, source});
    }
  }
};

export default {
  namespaced: true,
  state,
  getters,
  mutations,
  actions
};
