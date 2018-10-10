import Vue from 'vue/dist/vue.esm';
import App from '../components/App.vue';

document.addEventListener('DOMContentLoaded', () => {
  const app = new Vue({
    el: '#vue_app',
    data: {
      message: "Can you say hello?"
    },
    components: { App }
  });
});
