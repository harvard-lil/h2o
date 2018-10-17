import Vue from 'vue/dist/vue.esm';
import App from '../components/App.vue';
import '../config/axios';
import '../directives/selectionchange';

document.addEventListener('DOMContentLoaded', () => {
  const app = new Vue({
    el: '#vue_app',
    components: { App }
  });
});
