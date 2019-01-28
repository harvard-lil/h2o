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
    expandedDefault: true
  }),
  computed: {
    uiState() {
      // If a UI state for this annotation hasn't been set in the store, register it now
      return this.$store.getters['annotations_ui/getById'](this.annotation.id);
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
  },
  created() {
    if(!this.uiState) {
      this.$store.commit('annotations_ui/append', [
        {id: this.annotation.id,
         expanded: this.expandedDefault}
      ]);
    }
  }
}
</script>

<style lang="scss" scoped>
</style>
