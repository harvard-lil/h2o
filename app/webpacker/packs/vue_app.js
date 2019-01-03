import 'polyfills';
import Vue from 'vue/dist/vue.esm';

import store from '../store/index.js.erb';
import '../config/axios';
import '../directives/selectionchange';

import TheAnnotator from "../components/TheAnnotator.vue.erb";
import Elision from "../components/Elision";
import Replacement from "../components/Replacement";
import Highlight from "../components/Highlight";
import Link from "../components/Link";
import Note from "../components/Note";
import TheGlobalElisionExpansionButton from "../components/TheGlobalElisionExpansionButton";

document.addEventListener('DOMContentLoaded', () => {
  const app = new Vue({
    el: '#app',
    store,
    components: {
      TheAnnotator,
      Elision,
      Replacement,
      Highlight,
      Link,
      Note,
      TheGlobalElisionExpansionButton
    }
  });

  window.app = app;
});
