<template>
</template>

<script>
import AnnotationHandle from './AnnotationHandle';
import { createNamespacedHelpers } from 'vuex';
const { mapActions } = createNamespacedHelpers('annotations');

export default {
  components: {
    AnnotationHandle
  },
  props: {
    annotation: {type: Object},
    startOffset: {type: Number},
    endOffset: {type: Number}
  },
  data: () => ({
    expandedDefault: false
  }),
  computed: {
    uiState() {
      // If a UI state for this annotation hasn't been set in the store, register it now
      let state = this.$store.getters['annotations_ui/getById'](this.annotation.id);
      if(!state) {
        state = {id: this.annotation.id,
                 kind: this.annotation.kind,
                 start_offset: this.annotation.start_offset,
                 expanded: this.expandedDefault};

        // Only initialize the state if this is the beginning of the annotation
        if(!this.isNew && this.isHead){
          this.$nextTick(() => {
            // round this to the nearest 5 pixels because browsers
            // sometimes report different fractional pixels for
            // elements on the same line. We've picked "5" out of an
            // abundance of caution.
            state.headY = Math.round((this.$el.getBoundingClientRect().top + window.scrollY) / 5) * 5;
            this.$store.commit('annotations_ui/append', [state])
          });
        }
      }
      return state;
    },
    isNew() {
      return !this.annotation.id;
    },
    isHead() {
      return this.startOffset == this.annotation.start_offset;
    },
    isTail() {
      return this.endOffset == this.annotation.end_offset;
    }
  },
  methods: {
    ...mapActions(['destroy'])
  }
}
</script>

<style lang="scss" scoped>
</style>
