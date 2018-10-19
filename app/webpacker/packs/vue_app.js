import Vue from 'vue/dist/vue.esm';

import store from '../store/index.js.erb';
import '../config/axios';
import '../directives/selectionchange';

import TheAnnotator from '../components/TheAnnotator.vue.erb';
import AnnotationHandle from "../components/AnnotationHandle";

document.addEventListener('DOMContentLoaded', () => {
  const app = new Vue({
    el: '#app',
    store,
    components: {
      TheAnnotator,
      AnnotationHandle
    }
  });

  window.app = app;
});
