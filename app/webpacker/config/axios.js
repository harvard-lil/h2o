import Vue from 'vue/dist/vue.esm';
import AxiosConfig from 'axios';
import VueAxios from 'vue-axios';

const csrf_el = document.querySelector('meta[name=csrf-token]'),
      headers = csrf_el ? {'X-CSRF-Token': csrf_el.getAttribute('content')} : {};
const Axios = AxiosConfig.create({headers: headers});

Vue.use(VueAxios, Axios);
