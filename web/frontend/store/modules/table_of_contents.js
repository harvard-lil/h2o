import Axios from '../../config/axios';
import Vue from "vue";

const state = {
    toc: {}
};

const helpers = {
    resourcePath: ( casebook, subsection ) => {
        return !subsection ? `/casebook/${casebook}/toc` : `/casebook/${casebook}/toc/${subsection}`;
    },
    findNode: (toc, casebook, id) => {
        function dive(node, id) {
            if (node.id && node.id === id) {
                return node;
            }
            if (node.children) {
                let potential = node.children.map((n) =>dive(n, id)).filter(x => x);
                if (potential.length === 1) {
                    return potential[0];
                }
            }
            return null;
        }
        if (!(casebook in toc)) {
            return null;
        }
        if (!id) {
            return toc[casebook];
        }
        return dive(toc[casebook], id);
    }
};

const getters = {
    getNode: state => id => helpers.findNode(state.toc, id),
};


const mutations = {
    overwrite: (state, payload) => {
        Vue.set(state.toc,payload.id,payload);
    },
    delete: (state, payload) => {
        function deleteRecursive(node, id) {
            for (let ii = 0; ii < node.children.length; ii++) {
                if (node.children[ii].id === id) {
                    Vue.delete(node.children,ii);
                    ii--;
                } else {
                    deleteRecursive(node.children[ii],id);
                }
            }
        }
        if (!(payload.casebook in state.toc)) {
            return false;
        }
        return deleteRecursive(state.toc[payload.casebook], payload.id);
    },
    shuffle: (state, {id, children}) => {
        Vue.set(state.toc[id], 'children', children);
    }
};

const actions = {
    fetch: ({ commit }, {casebook,subsection}) => {
        if (!subsection || subsection === "") {
            subsection = null;
        }
        Axios.get(helpers.resourcePath(casebook, subsection))
            .then(resp => {
                if (!resp.data.id) {
                    resp.data.id = casebook;
                }
                commit('overwrite',resp.data);
            }, console.error);
    },
    deleteNode: ({ commit, state, dispatch }, {casebook, rootNode, targetId}) => {
        if (!targetId || targetId === "") {
            return false;
        }
        let node = helpers.findNode(state.toc, rootNode,  targetId);
        if (node === null) {
            return false;
        }
        return Axios.delete(helpers.resourcePath(casebook, targetId))
            .then(() => {
                commit('delete', {casebook:rootNode, id:targetId});
            }, () => {
                dispatch('fetch', {rootNode});
            });
    },
    moveNode: ({commit, state, dispatch}, {casebook, rootNode, targetId, pathTo}) => {
        let data = {newLocation: pathTo};
        if (rootNode != casebook) {
            data['within'] = rootNode;
        }
        return Axios.patch(helpers.resourcePath(casebook, targetId), data)
            .then(resp => {
                if (!resp.data.id) {
                    resp.data.id = casebook;
                }
                commit('overwrite', resp.data);
            }, () => {
                if (rootNode !== casebook) {
                    dispatch('fetch', {casebook, subsection: rootNode});
                } else {
                    dispatch('fetch', {casebook});
                }


            });
    }
};

export default {
    namespaced: true,
    state,
    getters,
    mutations,
    actions
};
