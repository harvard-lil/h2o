<template>
  <a @click.prevent="handleClick"><slot></slot></a>
</template>

<script>
import VueScrollTo from "vue-scrollto";
import { createNamespacedHelpers } from 'vuex';
const { mapMutations } = createNamespacedHelpers('annotations_ui');

export default {
  props: {
    enclosingAnnotationIds: {type: Array,
                             default: []}
  },
  computed: {
    id() {
      return this.$attrs.name.slice(2);
    },
    siblingName() {
      return this.$attrs.href.slice(1);
    },
    relatedAnnotationIds() {
      // If a UI state for this annotation hasn't been set in the store, register it now
      return this.$store.getters['footnotes_ui/getById'](this.id);
    }
  },
  methods: {
    ...mapMutations(['expandById']),
    handleClick() {
      this.expandById(this.relatedAnnotationIds);
      this.$nextTick(() => VueScrollTo.scrollTo(document.querySelector(`[name="${this.siblingName}"]`)));
    }
  },
  created() {
    this.$store.commit(
      'footnotes_ui/register',
      {id: this.id,
       annotationIds: this.enclosingAnnotationIds}
    );
  }
}
// I need to have the footnotes register their state, by ID, in vuex
// so that dependent links can expand their partner's annotations
</script>
