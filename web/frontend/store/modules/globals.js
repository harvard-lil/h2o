import _ from 'lodash';

const state = {
    casebook:null,
    section:null,
    inAuditMode: false
};
  
const getters = {
    casebook: (state) => () => {
        return state.casebook;
    },
    section: (state) => () => {
        return state.section;
    },
    inAuditMode: (state) => () => {
        return state.inAuditMode;
    }
};
  
const mutations = {
    setCasebook: (state,value) => state.casebook = value,
    setSection: (state,value) => state.section = value,
    setAuditMode: (state,value) => state.inAuditMode = value,
};
  
export default {
    namespaced: true,
    state,
    getters,
    mutations
};