import Axios from '../../config/axios';
import Vue from 'vue';
import _ from 'lodash';

const searchURL = '/search/cases/';

const state = {
    searches: {}
};

const helpers = {
    normalize: function normalize(query) {
        return query;
    }
};

const getters = {
    getSearch: state => query => state.searches[helpers.normalize(query)],
};

const mutations = {
    overwrite: (state, {query, results}) => {
        Vue.set(state.searches,helpers.normalize(query),results);
    },
    setPending: (state, query) => {
        Vue.set(state.searches, helpers.normalize(query), 'pending');
    },
    scrub: (state, query) => {
        Vue.delete(state.searches, query);
    }
};

const actions = {
    fetch: ({ state, commit, dispatch }, {query}) => {
        if (!_.has(state.searches, query)) {
            commit('setPending', query)
            Axios.get(searchURL + `?q=${encodeURI(query)}`)
                .then(resp => {
                    commit('overwrite', {query, results: resp.data.results});
                }, console.error);
            }
            dispatch('timeOutSearch', {query});
    },
    timeOutSearch: ({ state, commit }, {query}) => {
        const searchTimeout = 30000;
        setTimeout(() => {
            if (state.searches[query] === 'pending') {
                commit('scrub', {query});
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
