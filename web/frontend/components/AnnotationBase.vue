<!-- /* eslint-disable vue/valid-template-root */ -->
<template>
</template>
<!-- /* eslint-enable vue/valid-template-root */ -->

<script>
import AnnotationHandle from './AnnotationHandle';
import { createNamespacedHelpers } from 'vuex';
const { mapActions } = createNamespacedHelpers('annotations');

export default {
  components: {
    // are these used?
    AnnotationHandle  // eslint-disable-line vue/no-unused-components
  },
  props: {
    annotation: {type: Object,
                 required: true},
    // The startOffset, and endOffset here are for this
    // particular section of the rendered annotation. Annotation templates
    // can be split up across multiple HTML elements and each portion
    // needs to understand its context in the length in order to know
    // whether to show things like the annotation handle, which only
    // the first instance (the "head") of the template gets
    startOffset: {type: Number,
                  required: true},
    endOffset: {type: Number,
                required: true},
    isHead: {type: Boolean,
             required: true}
  },
  data: () => ({
    expandedDefault: true
  }),
  computed: {
    uiState() {
      return this.$store.getters['annotations_ui/getById'](this.annotation.id);
    },
    isNew() {
      return Math.sign(this.annotation.id) == -1;
    },
    isTail() {
      return this.endOffset == this.annotation.end_offset;
    },
    isEditable() {
      return this.$store.getters["resources_ui/getEditability"];
    },
    hasHandle() {
      return this.isEditable && this.isHead && !this.isNew;
    }
  },
  methods: {
    ...mapActions(['destroy', 'createAndUpdate'])
  },
  created() {
    if(this.isHead && this.isNew && ['highlight', 'elide'].includes(this.annotation.kind)){
      this.createAndUpdate(
        {obj: this.annotation, vals: {}}
      );
    }

    if(!this.uiState) {
      this.$store.commit('annotations_ui/append', [
        {id: this.annotation.id,
         expanded: this.expandedDefault,
         headY: null}
      ]);
    }
  }
}
</script>

<style lang="scss" scoped>
</style>
