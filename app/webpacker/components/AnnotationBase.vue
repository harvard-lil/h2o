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
  props: ['annotationId',
          'hasHandle'],
  computed: {
    annotation() {
      return this.$store.getters['annotations/getById'](this.annotationId);
    },
    uiState() {
      return this.$store.getters['annotations_ui/getById'](this.annotationId);
    }
  },
  methods: {
    ...mapActions(['destroy'])
  }
}
</script>

<style>
</style>
