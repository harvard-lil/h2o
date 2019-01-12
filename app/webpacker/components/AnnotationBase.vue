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
                 expanded: this.expandedDefault};
        this.$store.commit('annotations_ui/append', [state]);
      }
      return state;
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
