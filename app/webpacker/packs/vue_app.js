import 'polyfills';
import Vue from 'vue/dist/vue.esm';

import store from '../store/index.js.erb';
import '../config/axios';
import '../directives/selectionchange';

import contenteditableDirective from 'vue-contenteditable-directive';
Vue.use(contenteditableDirective);

import TheResourceBody from "../components/TheResourceBody";

document.addEventListener('DOMContentLoaded', () => {
  const app = new Vue({
    el: '#app',
    store,
    components: {
      TheResourceBody
    }
  });

  window.app = app;
});
