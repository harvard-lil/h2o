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
    markForDeletion: (state, {casebook, targetId}) => {
        let node = helpers.findNode(state.toc, casebook, targetId);
        if (node !== null) Vue.set(node, 'confirmDelete', true);
    },
    cancelDeletion: (state, {casebook, targetId}) => {
        let node = helpers.findNode(state.toc, casebook, targetId);
        if (node !== null) Vue.delete(node, 'confirmDelete');
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
    },

    showChildren: (state, {id}) => {
        let target = helpers.findNode(state.toc, id);
        Vue.delete(target, 'collapsed');
    },
    hideChildren: (state, {id}) => {
        let target = helpers.findNode(state.toc, id);
        Vue.set(target, 'collapsed', true);
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
    deleteNode: ({ commit, state }, {casebook, targetId}) => {
        if (!targetId || targetId === "") {
            return false;
        }
        let node = helpers.findNode(state.toc, casebook,  targetId);
        if (node === null) {
            return false;
        }
        return Axios.delete(helpers.resourcePath(casebook, targetId))
            .then(() => {
                commit('delete', {casebook, id:targetId});
            }, console.error);
    },
    moveNode: ({commit, state}, {casebook, targetId, pathTo}) => {
        return Axios.patch(helpers.resourcePath(casebook, targetId), {newLocation:pathTo})
            .then(resp => {
                if (!resp.data.id) {
                    resp.data.id = casebook;
                }
                commit('overwrite', resp.data);
            },
            console.error);
    }
};

export default {
    namespaced: true,
    state,
    getters,
    mutations,
    actions
};
