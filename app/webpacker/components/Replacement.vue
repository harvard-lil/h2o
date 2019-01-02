<template>
<span class="replacement">
  <button v-if="hasHandle"
          @click="toggleExpansion(ui_state)"
          aria-label="elided text"
          v-bind:aria-expanded="ui_state.expanded"
          v-bind:class="{expanded: ui_state.expanded}">
  </button>
  <span v-if="ui_state.expanded"
        class="selected-text">
    <slot></slot>
  </span>
  <span v-else
        class="text"
        contenteditable="true">{{escapedContent}}</span>
</span>
</template>

<script>
import { createNamespacedHelpers } from 'vuex';
const { mapMutations } = createNamespacedHelpers('annotations_ui');

export default {
  props: ['annotationId',
          'hasHandle',
          'escapedContent'],
  computed: {
    annotation() {
      return this.$store.getters['annotations/getById'](this.annotationId);
    },
    ui_state() {
      return this.$store.getters['annotations_ui/getById'](this.annotationId);
    }
  },
  methods: {
    ...mapMutations(['toggleExpansion'])
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';

.replacement {
  margin: 0 6px;
  padding: 0 6px;
}
button {
  display: inline-block;
  cursor: zoom-in;
  border: none;
  background-color: $light-gray;
  color: $light-blue;
  &::before {
    font-weight: $bold;
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
.selected-text {
  padding: 7px;
  display: inline;
  color: #555;
  border-radius: 3px;
  background-color: $light-gray;
}  
.text {
  pointer-events: none;
}
.text:empty::before {
  content: 'Enter replacement text';
  color: $dark-gray;
  pointer-events: none;
}
.active .text:empty::before {
  content: ' ';
  pointer-events: none;
}
</style>
