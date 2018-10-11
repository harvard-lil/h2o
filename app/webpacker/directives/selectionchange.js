import Vue from 'vue/dist/vue.esm';

var handler = null;

Vue.directive('selectionchange', {
  inserted: function (el, binding) {
    handler = function (evt) {
      const sel = document.getSelection();
      if (el.contains(sel.anchorNode)) {
        binding.value(evt, sel);
      }
    };
    document.addEventListener('selectionchange', handler);
  },
  unbind: function(el, binding) {
    document.removeEventListener('selectionchange', handler);
  }
});
