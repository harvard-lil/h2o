import 'polyfills';
import Vue from 'vue/dist/vue.esm';

import store from '../store/index.js.erb';
import '../config/axios';
import '../directives/selectionchange';

import ResourceBody from "../components/ResourceBody";
import TheAnnotator from "../components/TheAnnotator.vue.erb";
import ElisionAnnotation from "../components/ElisionAnnotation";
import ReplacementAnnotation from "../components/ReplacementAnnotation";
import HighlightAnnotation from "../components/HighlightAnnotation";
import LinkAnnotation from "../components/LinkAnnotation";
import NoteAnnotation from "../components/NoteAnnotation";
import TheGlobalElisionExpansionButton from "../components/TheGlobalElisionExpansionButton";

document.addEventListener('DOMContentLoaded', () => {
  const app = new Vue({
    el: '#app',
    store,
    components: {
      ResourceBody,
      TheAnnotator,
      ElisionAnnotation,
      ReplacementAnnotation,
      HighlightAnnotation,
      LinkAnnotation,
      NoteAnnotation,
      TheGlobalElisionExpansionButton
    }
  });

  window.app = app;
});
