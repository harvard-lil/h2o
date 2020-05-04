<template>
<portal to="modal-target">
<transition name="fade">
  <focus-trap :active="hasFocusTarget" :initial-focus="wrappedFocus">
  <div id="modal"
       aria-labelledby="modal-title"
       tabindex="-1"
       @click.self="$emit('close')">
    <div class="modal-dialog"
         role="document">
      <div class="modal-content">
        <div class="modal-header">
          <button type="button"
                  class="close"
                  aria-label="Close"
                  @click="$emit('close')">
            <span aria-hidden="true">×</span>
          </button>
          <h4 id="modal-title" class="modal-title">
            <slot name="title"></slot>
          </h4>
        </div>
        <div class="modal-body">
          <slot name="body"></slot>
        </div>
      </div>
    </div>
  </div>
  </focus-trap>
</transition>
</portal>
</template>

<script>
import PortalVue from "portal-vue";
import Vue from "vue";
import { FocusTrap } from 'focus-trap-vue';
Vue.use(PortalVue)

Vue.directive('focus', {
    inserted: function (el) {
        el.focus()
    }
})

export default {
  components: {
    FocusTrap
  },
  props: ['initialFocus'],
  computed: {
    wrappedFocus: function() {
      return this.initialFocus;
    },
    hasFocusTarget: function() {
      return !! this.initialFocus;
    }
  },
  methods: {
    onKey(e) {
      if(e.key == "Escape") this.$emit("close");
    }
  },
  created: function () {
    let nm = document.getElementById('non-modal');
    nm.style.position = "relative";
    nm.setAttribute('aria-hidden', 'true');
    nm.style.overflow = "unset";
    document.body.classList.add('modal-open');
    window.addEventListener('keydown', this.onKey)
  },
  beforeDestroy: function () {
    let nm = document.getElementById('non-modal');
    nm.removeAttribute('aria-hidden');
    document.body.classList.remove('modal-open');
    nm.style = "";
    window.removeEventListener('keydown', this.onKey)
  }
}
</script>

<style lang="scss" scoped>
@import "../styles/vars-and-mixins";

#modal {
  position: fixed;
  z-index: 9998;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(255, 255, 255, .85);
  .modal-dialog {
      max-width: 1000px;
      min-width: 600px;
      width: unset;
    .modal-content {
      max-height: calc(100vh - 225px);
      overflow-y: scroll;

    }
  }
}
.modal-dialog {
    margin-top: 90px;
}

/*
 * Many styles for this component are coming from Bootstrap
 * TODO: transition styles into this component
 */
</style>
