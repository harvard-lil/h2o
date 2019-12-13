<template>
<transition name="fade">
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
</transition>
</template>

<script>
export default {
  methods: {
    onKey(e) {
      if(e.key == "Escape") this.$emit("close");
    }
  },
  created: function () {
    window.addEventListener('keydown', this.onKey)
  },
  beforeDestroy: function () {
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
}

/*
 * Many styles for this component are coming from Bootstrap
 * TODO: transition styles into this component
 */
</style>
