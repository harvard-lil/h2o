<template>
<button class="toggle"
        data-exclude-from-offset-calcs="true"
        @click="toggleExpansion(uiState)"
        aria-label="elided text"
        :aria-expanded="uiState.expanded"
        :class="{expanded: uiState.expanded}"></button>
</template>

<script>
import { createNamespacedHelpers } from 'vuex';
const { mapMutations } = createNamespacedHelpers('annotations_ui');

export default {
  props: {
    uiState: {type: Object}
  },
  methods: {
    ...mapMutations(['toggleExpansion'])
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';

.toggle {
  display: inline-block;
  cursor: zoom-in;
  border: none;
  background-color: $translucent-light-gray;
  color: $light-blue;
  padding: 0 0.5em;
  &::before {
    font-weight: $bold;
    content: '...';
  }
  &:focus {
    @include generic-focus-styles;
  }
  &.expanded {
    cursor: zoom-out;
    &::before {
      content: 'hide';
    }
  }
}
</style>
