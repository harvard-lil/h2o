import 'polyfills';
import Vue from 'vue/dist/vue.esm';

import store from '../store/index.js.erb';
import '../config/axios';
import '../directives/selectionchange';

import TheAnnotator from "../components/TheAnnotator.vue.erb";
import AnnotationHandle from "../components/AnnotationHandle";
import Elision from "../components/Elision";
import TheGlobalElisionExpansionButton from "../components/TheGlobalElisionExpansionButton";

document.addEventListener('DOMContentLoaded', () => {
  const app = new Vue({
    el: '#app',
    store,
    components: {
      TheAnnotator,
      AnnotationHandle,
      Elision,
      TheGlobalElisionExpansionButton
    }
  });

  window.app = app;
});
