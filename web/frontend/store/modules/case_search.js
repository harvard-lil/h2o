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
    let searches = state.searches[qKey];
    if (!searches) return {unRun: true};
    let results = [];
    let sources = [];
    let keys = _.keys(_.groupBy(searches.map(results => _.isArray(results) ? 'completed' : results), x => x)).filter(x => x !== 'disabled');
    let allDisabled = keys.length === 0;
    let allCompleted = keys.length === 1 && keys[0] === 'completed';
    let allPending = keys.length === 1 && keys[0] === 'pending';
    let mixedResults = keys.length > 1;
    searches.forEach((search, index) => {
      if (_.isArray(search) && search.length === 0) return;
      let source = _.find(state.sources, ({id}) => id === search[0].source_id);
      if (!source) return;
      if (_.isArray(search)) {
        source.status = 'completed';
        results = results.concat(search.map(result => ({sourceName: source.name, ...result})));
      } else {
        source.status = source.status === 'timeout' ? 'disabled' : source.results;
      }
      sources.push(source);
    });
    let emptyResults = allCompleted && results.length === 0;
    return {sources, results, allDisabled, allCompleted, allPending, mixedResults, emptyResults};
  },
  getSources: state => {
    return state.sources;
  }
};

const mutations = {
  setSources: (state, sources) => {
    sources.forEach((source, sourceIndex) => {
      source.search_regexes.forEach(search_regex => {
        search_regex.regex = new RegExp(search_regex.regex);
      });
      source.sourceIndex = sourceIndex;
    });
    Vue.set(state, 'sources', sources);
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
      Vue.set(state.searches, qKey, state.sources.map(() => 'disabled'));
    }
  },
  toggleSourceEnabled: (state, sourceIndex) => {
    state.sources[sourceIndex].enabled = !state.sources[sourceIndex].enabled;
  }
};

const actions = {
  fetchForSource: ({state, commit, dispatch}, {queryObj, source }) => {
    if (queryObj === {}) return;
    commit('initializeSearch', queryObj);
    let qKey = helpers.normalize(queryObj);
    if (_.hasIn(state, ['searches', qKey]) &&
        state.searches[qKey].length >= source.sourceIndex &&
        !_.includes(['timeout', 'disabled'], state.searches[qKey][source.sourceIndex])) return;
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
  fetchForAllSources: ({state, commit, dispatch}, {queryObj}) => {
    for(let source of state.sources) {
      dispatch('fetchForSource', {queryObj, source});
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
      if (state.searches[helpers.normalize(queryObj)][source.sourceIndex] === 'pending') {
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
