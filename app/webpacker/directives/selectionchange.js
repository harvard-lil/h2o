import Vue from 'vue';

const handlers = new WeakMap();
const prev_in_el = new WeakMap();

// Accepts a handler in the form of function(event, selection)
// where selection will be null in the event the user has selected
// something outside of the element on which this directive has been placed.
Vue.directive('selectionchange', {
  inserted(el, binding) {
    handlers.set(el, function (evt) {
      const sel = document.getSelection();
      const in_el = el.contains(sel.anchorNode);
      const lost_focus = prev_in_el.get(el) && !in_el;
      if (in_el || lost_focus) {
        binding.value(evt, lost_focus ? null : sel);
      }
      prev_in_el.set(el, in_el);
    });
    document.addEventListener('selectionchange', handlers.get(el));
  },
  unbind(el, binding) {
    document.removeEventListener('selectionchange', handlers.get(el));
    handlers.delete(el);
    prev_in_el.delete(el);
  }
});
