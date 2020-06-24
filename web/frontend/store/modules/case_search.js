import Axios from '../../config/axios';
import Vue from 'vue';
import _ from 'lodash';

const searchURL = '/search/cases/';

const state = {
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
        console.log("CS Getting: " + qKey);
        return state.searches[qKey]
    },
};

const mutations = {
    overwrite: (state, {queryObj, results}) => {
        const qKey = helpers.normalize(queryObj);
        console.log("CS Saving Results: " + qKey);
        Vue.set(state.searches,qKey,results);
    },
    setPending: (state, queryObj) => {
        const qKey = helpers.normalize(queryObj);
        Vue.set(state.searches, qKey, 'pending');
    },
    scrub: (state, queryObj) => {
        Vue.delete(state.searches, helpers.normalize(queryObj));
    }
};

const actions = {
    fetch: ({ state, commit, dispatch }, queryObj) => {
        const qKey = helpers.normalize(queryObj);
        console.log("CS Fetching: " + qKey);
        if (!_.has(state.searches, qKey)) {
            commit('setPending', queryObj)
            Axios.get(searchURL + `?${helpers.encodeQuery(queryObj)}`)
                .then(resp => {
                    commit('overwrite', {queryObj, results: resp.data.results});
                }, console.error);
            }
            dispatch('timeOutSearch', queryObj);
    },
    timeOutSearch: ({ state, commit }, queryObj) => {
        const searchTimeout = 30000;
        setTimeout(() => {
            if (state.searches[helpers.normalize(queryObj)] === 'pending') {
                commit('scrub', queryObj);
            }
        }, searchTimeout)

    }
};

export default {
    namespaced: true,
    state,
    getters,
    mutations,
    actions
};
