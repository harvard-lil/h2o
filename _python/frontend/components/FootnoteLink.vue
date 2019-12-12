<template>
  <a @click.prevent="handleClick"><slot></slot></a>
</template>

<script>
import VueScrollTo from "vue-scrollto";
import { createNamespacedHelpers } from 'vuex';
const { mapActions } = createNamespacedHelpers('annotations_ui');

export default {
  props: {
    startOffset: {type: Number,
                  required: true},
    endOffset: {type: Number,
                required: true}
  },
  computed: {
    id() {
      return this.$attrs.name || this.$attrs.id;
    },
    siblingId() {
      return (this.$attrs.href || "").slice(1);
    },
    enclosingAnnotationIds() {
      return this.$store.getters['annotations/getWithinOffsets'](this.startOffset, this.endOffset);
    },
    relatedAnnotationIds() {
      return this.$store.getters['footnotes_ui/getById'](this.siblingId) || [];
    }
  },
  methods: {
    ...mapActions(['expandById']),
    handleClick() {
      this.expandById(this.relatedAnnotationIds);
      this.$nextTick(() => VueScrollTo.scrollTo(document.querySelector(`[id="${this.siblingId}"], [name="${this.siblingId}"]`)));
    }
  },
  created() {
    // footnotes register their state, by ID, in vuex
    // so that dependent links can expand their partner's annotations
    this.$store.commit(
      'footnotes_ui/register',
      {id: this.id,
       annotationIds: this.enclosingAnnotationIds}
    );
  }
}
</script>
