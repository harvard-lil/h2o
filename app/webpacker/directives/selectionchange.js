import Vue from 'vue/dist/vue.esm';

const state = new WeakMap();

Vue.directive('selectionchange', {
  inserted: function (el, binding) {
    state.set(el, function (evt) {
      const sel = document.getSelection();
      if (el.contains(sel.anchorNode)) {
        binding.value(evt, sel);
      }
    });
    document.addEventListener('selectionchange', state.get(el));
  },
  unbind: function(el, binding) {
    document.removeEventListener('selectionchange', state.get(el));
    state.delete(el);
  }
});
