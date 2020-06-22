import _ from 'lodash';

const state = {};
  
const getters = {
    bagContents: () => (state, {bagName, defaultValue}) => {
        const ret = (_.has(state,bagName)) ? state[bagName] : defaultValue;
        return ret;
    }
};
  
const mutations = {
    overwrite: (state,{bagName,value}) => state[bagName] = value
};
  
export default {
    namespaced: true,
    state,
    getters,
    mutations
};