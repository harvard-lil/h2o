<template>
<span class="toggle"
      role="button"
      tabindex="0"
      data-exclude-from-offset-calcs="true"
      :aria-expanded="uiState.expanded || 'false'"
      :class="{expanded: uiState.expanded}"
      @click="toggleExpansion(uiState)"
      @keydown.enter="toggleExpansion(uiState)"
      @keydown.space.prevent="toggleExpansion(uiState)">
  <slot name="expanded"
        v-if="uiState.expanded"></slot>
  <slot name="collapsed"
        v-else></slot>
</span>
</template>

<script>
import { createNamespacedHelpers } from 'vuex';
const { mapActions } = createNamespacedHelpers('annotations_ui');

export default {
  props: {
    annotation: {type: Object,
                 required: true}
  },
  computed: {
    uiState() {
      return this.$store.getters['annotations_ui/getById'](this.annotation.id) || {};
    }
  },
  methods: {
    ...mapActions(['toggleExpansion'])
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';

.toggle {
  background-color: $translucent-light-gray;
  color: $light-blue;
  padding: 0.35em;
  &:empty::before {
    font-weight: $bold;
    padding: 0 0.15em;
    content: '...';
  }
  &.expanded:empty::before {
    content: 'hide';
  }
}
</style>
