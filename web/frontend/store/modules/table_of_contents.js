import _ from 'lodash';
import Axios from '../../config/axios';
import Vue from "vue";

const state = {
    toc: {},
    augments: {}
};

function augmentNode(node, traits) {
    _.keys(traits).forEach(k => Vue.set(node, k, traits[k]));
}

const helpers = {
    addCSSClass: (cls) => {
        return (node) => {
            node.cssClasses = _.get(node, 'cssClasses', []).filter(x => x !== cls).concat([cls]);
            return node;
        }
    },
    removeCSSClass: (cls) => {
        return (node) => {
            node.cssClasses = _.get(node, 'cssClasses', []).filter(x => x !== cls);
            return node;
        }
    },
    addFlag: (flagName) => {
        return (node) => {
            node[flagName] = true;
            return node;
        };
    },
    removeFlag: (flagName) => {
        return (node) => {
            node[flagName] = false;
            return node;
        }
    },
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
            return pred(node) ? node : _.find(_.flatMap(node.children || [], dive).filter(_.identity), pred);
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
    findNode: (toc, id) => {
        const matchingNode = (node) => node.id === id;
        let trees = _.values(toc).map((tree) => helpers.firstMatching(tree, matchingNode));
        return _.find(trees, _.identity);
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
    augmentNode,
    augmentNodes: (tree, augments) => {
        const base = {};
        function dive(node) {
            let traits = _.get(augments, node.id, base);
            augmentNode(node, traits);
            (node.children || []).forEach(dive);
        }
        dive(tree);
    }
};

const getters = {
    getNode: state => (id) => helpers.findNode(state.toc, id),
    auditTargets: state => (casebook) => helpers.auditIDs(state.toc, casebook)
};

const collapseNode = (node) => helpers.addCSSClass('collapsed')(helpers.addFlag('collapsed')(node))
const expandNode = (node) => helpers.removeCSSClass('collapsed')(helpers.removeFlag('collapsed')(node))
//const setLoading = helpers.addFlag('loading')
const setLoaded = (node) => helpers.removeCSSClass('loading')(helpers.addCSSClass('loaded')(node))
const setAudit = helpers.addFlag('audit')
const removeAudit = helpers.removeFlag('audit')

const mutations = {
    overwrite: (state, payload) => {
        helpers.augmentNodes(payload, state.augments);
        Vue.set(state.toc, payload.id, payload);
    },
    delete: (state, payload) => {
        function deleteRecursive(node, id) {
            function childStream(node) {
                return [node.id].concat(_.flatMap(node.children || [], childStream));
            }
            for (let ii = 0; ii < node.children.length; ii++) {
                if (node.children[ii].id === id) {
                    let children = childStream(node.children[ii]) || [];
                    children.forEach(child => {
                        if (_.has(state.augments, child)) {
                            Vue.delete(state.augments, child);
                        }
                    })
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
        deleteRecursive(state.toc[payload.casebook], payload.id);
        return state.toc;
    },
    shuffle: (state, { id, children }) => {
        if (id in state.toc) {
            children.forEach(node => helpers.augmentNodes(node, state.augments));
            Vue.set(state.toc[id], 'children', children);
        }
    },
    modifyAugment: (state, { id, ids, modifyFn }) => {
        let toUpdate = (id ? [id] : []).concat(ids || []);

        toUpdate.forEach(ii => {
            let updatedNode = modifyFn(_.get(state.augments, ii, {}));
            Vue.set(state.augments, ii, updatedNode);
            let node = helpers.findNode(state.toc, ii);
            if (!node) {
                if (_.has(state.augments, ii)) {
                    Vue.delete(state.augments, ii);
                }
                return;
            }
            helpers.augmentNode(node, updatedNode);
        })
    }
};

const actions = {
    revealNode: ({ commit, state }, { casebook, id }) => {
        let ids = helpers.findPath(state.toc[casebook], node => node.id === id);
        commit('modifyAugment', { ids, modifyFn: expandNode });
    },
    toggleCollapsed: ({ commit }, { id }) => {
        commit('modifyAugment', {
            id,
            modifyFn: (node) => _.get(node, 'collapsed', false) ? expandNode(node) : collapseNode(node)
        });
    },
    setAudit: ({ commit, state }, { id }) => {
        let currentAudits = _.keys(state.augments).filter(k => _.get(state.augments[k], 'audit', false)).map(parseInt);
        commit('modifyAugment', { ids: currentAudits, modifyFn: removeAudit });
        commit('modifyAugment', { id, modifyFn: setAudit });
    },
    clearAudit: ({ commit }, { id }) => {
        commit('modifyAugment', { id, modifyFn: removeAudit });
    },
    slowMerge: ({ commit, state }, { casebook, newToc }) => {
        // Compare the current state to the newToc and get a list of new nodes
        // Cascade a delay for the new nodes, first node immediate, each after that appearing in a sec.
        // animationState: 'loading' -> 'loaded'
        function notInPreviousTree(node) {
            return !helpers.findNode(state.toc, node.id);
        }

        let newNodes = helpers.flatFilter(newToc, notInPreviousTree);
        
        const delayGap = 250;
        newNodes.forEach(node => {
            state.augments[node.id] = {cssClasses: ['loading', 'collapsed'], collapsed: node.children.length > 0};
            node.collapsed = true;
            node.cssClasses = ['loading', 'collapsed'];
        })
        commit('overwrite', newToc);
        setTimeout(() => {
            commit('modifyAugment', {
                ids: newNodes.map(x => x.id),
                modifyFn: setLoaded
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
        let node = helpers.findNode(state.toc, targetId);
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
