<template>
<span class="toggle"
      role="button"
      tabindex="0"
      data-exclude-from-offset-calcs="true"
      :aria-label="ariaLabel"
      :aria-expanded="uiState.expanded || 'false'"
      :class="{expanded: uiState.expanded}"
      @click="toggleExpansion(uiState)"
      @keydown.enter="toggleExpansion(uiState)"
      @keydown.space.prevent="toggleExpansion(uiState)">
  <slot name="expanded"
        v-if="uiState.expanded">hide</slot>
  <slot name="collapsed"
        v-else><strong class="ellipsis">...</strong></slot>
</span>
</template>

<script>
import { createNamespacedHelpers } from 'vuex';
const { mapActions } = createNamespacedHelpers('annotations_ui');

export default {
  props: {
    annotation: {type: Object,
                 required: true},
    ariaLabel: {type: String,
                required: false}
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
}
.ellipsis {
  padding: 0 0.15em;
  text-decoration: none;
}
</style>
