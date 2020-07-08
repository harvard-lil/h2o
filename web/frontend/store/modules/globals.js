import _ from 'lodash';

const state = {
    casebook:null,
    section:null
};
  
const getters = {
    casebook: (state) => () => {
        return state.casebook;
    },
    section: (state) => () => {
        return state.section;
    }
};
  
const mutations = {
    setCasebook: (state,value) => state.casebook = value,
    setSection: (state,value) => state.section = value
};
  
export default {
    namespaced: true,
    state,
    getters,
    mutations
};