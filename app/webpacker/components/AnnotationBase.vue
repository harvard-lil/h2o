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
    startOffset: {type: Number}
  },
  computed: {
    uiState() {
      return this.$store.getters['annotations_ui/getById'](this.annotation.id);
    },
    isHead() {
      return this.startOffset == this.annotation.start_offset;
    }
  },
  methods: {
    ...mapActions(['destroy'])
  }
}
</script>

<style lang="scss" scoped>
</style>
