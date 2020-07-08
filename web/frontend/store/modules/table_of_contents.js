import _ from 'lodash';
import Axios from '../../config/axios';
import Vue from "vue";

const state = {
    toc: {},
    augments: {},
    augmentedToc: {}
};

const helpers = {
    flatFilter: (tree, filterFn) => {
        // Return any node for which filterFn returns true
        function dive(node) {
            let ret = filterFn(node) ? [node] : [];
            return ret.concat(_.flatMap(node.children || [], dive))
        }
        return dive(tree);
    },
    pruneFilter: (tree, filterFn) => {
        // Return any node for which filterFN returns true for all parents and itself
        function dive(node) {
            return !filterFn(node) ? [] : [node].concat(_.flatMap(node.children || [], dive));
        }
        return dive(tree);
    },
    firstMatching: (tree, pred) => {
        function dive(node) {
            return pred(node) ? node : _.find(_.flatMap(node.children || [],dive).filter(_.identity), pred);
        }
        return dive(tree);
    },
    findPath: (tree, pred) => {
        function dive(node, path) {
            let nextPath = path.concat([node.id]);
            return pred(node) ? [{ path: nextPath }] : _.flatMap(node.children || [], x => dive(x, nextPath));
        }
        return _.get(dive(tree, []), '0.path', []);
    },
    resourcePath: (casebook, subsection) => {
        return !subsection ? `/casebook/${casebook}/toc` : `/casebook/${casebook}/toc/${subsection}`;
    },
    findNode: (toc, casebook, id) => {
        if (!(casebook in toc)) {
            return null;
        }
        if (!id) {
            return toc[casebook];
        }
        return helpers.firstMatching(toc[casebook], (node) => node.id === id);
    },
    auditIDs: (toc, casebook) => {
        function isTemp(node) {
            return node.resource_type && node.resource_type === 'Temp'
        }
        if (!(casebook in toc)) {
            return []
        }
        return helpers.flatFilter(toc[casebook], isTemp).map(node => node.id);
    },
    augmentNodes: (tree, augments) => {
        const base = {};
        function dive(node) {
            let traits = _.get(augments, node.id, base);
            let modified = _.merge(_.omit(_.cloneDeep(node), _.keys(traits)), traits);
            modified.children = _.map(modified.children || [], dive);
            return modified;
        }
        return dive(tree);
    }
};

const getters = {
    getRawNode: state => (casebook, id) => helpers.findNode(state.toc, casebook, id),
    getAugmentedNode: state => (casebook, id) => {
        let node = helpers.findNode(state.toc, casebook, id);
        return node && helpers.augmentNodes(node, state.augments);
    },
    auditTargets: state => (casebook) => helpers.auditIDs(state.toc, casebook)
};


const mutations = {
    overwrite: (state, payload) => {
        Vue.set(state.toc, payload.id, payload);
        Vue.set(state.augmentedToc, payload.id, helpers.augmentNodes(payload, state.augments));
    },
    delete: (state, payload) => {
        function deleteRecursive(node, id) {
            for (let ii = 0; ii < node.children.length; ii++) {
                if (node.children[ii].id === id) {
                    Vue.delete(node.children, ii);
                    ii--;
                } else {
                    deleteRecursive(node.children[ii], id);
                }
            }
        }
        if (!(payload.casebook in state.toc)) {
            return false;
        }
        let rawToc = deleteRecursive(state.toc[payload.casebook], payload.id);
        Vue.set(state.augmentedToc, payload.casebook, helpers.augmentNodes(state.toc[payload.casebook], state.augments));
        return rawToc;
    },
    shuffle: (state, { id, children }) => {
        if (id in state.toc) {
            Vue.set(state.toc[id], 'children', children);
            Vue.set(state.augmentedToc, id, helpers.augmentNodes(state.toc[id], state.augments));
        }
    },
    modifyAugment: (state, { id, ids, modifyFn }) => {
        if (id) {
            let updatedNode = modifyFn(_.get(state.augments, id, {}));
            Vue.set(state.augments, id, updatedNode);
        }
        if (ids) {
            ids.forEach(ii => {
                let updatedNode = modifyFn(_.get(state.augments, ii, {}));
                Vue.set(state.augments, ii, updatedNode);
            })
        }
        for (let k in state.toc) {
            Vue.set(state.augmentedToc, k, helpers.augmentNodes(state.toc[k], state.augments));
        }
    }
};

const actions = {
    revealNode: ({ commit, state }, { casebook, id }) => {
        let ids = helpers.findPath(state.toc[casebook], node => node.id === id);
        commit('modifyAugment', {
            ids, modifyFn: (node) => {
                delete node['collapsed'];
                delete node['children'];
            }
        })
    },
    toggleCollapsed: ({ commit }, { id }) => {
        commit('modifyAugment', {
            id, modifyFn: (node) => {
                if ('collapsed' in node) {
                    delete node['children'];
                    delete node['collapsed'];
                } else {
                    node.collapsed = true;
                    node.children = [];
                }
                return node;
            }
        });
    },
    setAudit: ({ commit, state }, { id }) => {
        let currentAudits = _.keys(state.augments).filter(k => _.has(state.augments[k], 'audit'));
        commit('modifyAugment', { ids: currentAudits, modifyFn: (node) => { delete node['audit']; return node; } });
        commit('modifyAugment', { id, modifyFn: (node) => { node.audit = true; return node; } });
    },
    clearAudit:({ commit }, { id }) => {
        commit('modifyAugment', { id, modifyFn: (node) => { delete node['audit']; return node; } });
    },
    slowMerge: ({ commit, state }, { casebook, newToc }) => {
        // Compare the current state to the newToc and get a list of new nodes
        // Cascade a delay for the new nodes, first node immediate, each after that appearing in a sec.
        // animationState: 'loading' -> 'loaded'
        function notInPreviousTree(node) {
            return !helpers.findNode(state.toc, casebook, node.id);
        }

        let newNodes = helpers.flatFilter(newToc, notInPreviousTree);
        newNodes.forEach(node => node.animationState = 'loading');
        commit('modifyAugment', {
            ids: newNodes.filter(node => node.children.length > 0).map(node => node.id),
            modifyFn: (node) => {
                node.collapsed = true;
                node.children = [];
                return node;
            }
        });
        const delayGap = 250;
        commit('overwrite', newToc);
        setTimeout(() => {
            commit('modifyAugment', {
                ids: newNodes.map(x => x.id),
                modifyFn: (node) => {
                    node.animationState = 'loaded';
                    return node;
                }
            })
        }, delayGap);
    },
    fetch: ({ commit }, { casebook, subsection }) => {
        if (!subsection || subsection === "") {
            subsection = null;
        }
        Axios.get(helpers.resourcePath(casebook, subsection))
            .then(resp => {
                if (!resp.data.id) {
                    resp.data.id = casebook;
                }
                commit('overwrite', resp.data);
            }, console.error);
    },
    deleteNode: ({ commit, state, dispatch }, { casebook, rootNode, targetId }) => {
        if (!targetId || targetId === "") {
            return false;
        }
        let node = helpers.findNode(state.toc, rootNode, targetId);
        if (node === null) {
            return false;
        }
        return Axios.delete(helpers.resourcePath(casebook, targetId))
            .then(() => {
                commit('delete', { casebook: rootNode, id: targetId });
            }, () => {
                dispatch('fetch', { casebook: rootNode });
            });
    },
    moveNode: ({ commit, state, dispatch }, { casebook, rootNode, moverId, parent, index }) => {
        let data = { parent, index };
        if (parent === null && rootNode != casebook) {
            data['parent'] = rootNode;
        }
        return Axios.patch(helpers.resourcePath(casebook, moverId), data)
            .then(resp => {
                if (!resp.data.id) {
                    resp.data.id = casebook;
                }
                commit('overwrite', resp.data);
            }, () => {
                if (rootNode !== casebook) {
                    dispatch('fetch', { casebook, subsection: rootNode });
                } else {
                    dispatch('fetch', { casebook });
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
