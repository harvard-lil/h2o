import Vue from 'vue/dist/vue.esm';
import App from '../app.vue';

document.addEventListener('DOMContentLoaded', () => {
  const app = new Vue({
    el: '#hello',
    data: {
      message: "Can you say hello?"
    },
    components: { App }
  });
});
