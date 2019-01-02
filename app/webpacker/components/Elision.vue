<template>
<span class="elision">
  <span v-show="ui_state.expanded" class="selected-text"><slot></slot></span><!--
  whitespace affects offset counts so using this comment for code formatting
--><span data-exclude-from-offset-calcs="true">
    <template v-if="hasHandle">
      <button class="handle"
              aria-label="Edit annotation"
              v-bind:style="{right: offsetRight + 'px'}"
              @click.prevent="$refs.menu.open">✎</button>
      <button class="toggle"
              @click="toggleExpansion(ui_state)"
              aria-label="elided text"
              v-bind:aria-expanded="ui_state.expanded"
              v-bind:class="{expanded: ui_state.expanded}"></button>
    </template>
    <ContextMenu ref="menu">
      <ul>
        <li>
          <a @click="toggleExpansion(ui_state)">
            <template v-if="ui_state.expanded">Hide</template>
            <template v-else>Reveal</template>
            original text
          </a>
        </li>
        <li>
          <a @click="destroy(annotation)">Remove elision</a>
        </li>
      </ul>
    </ContextMenu>
  </span>
</span>
</template>

<script>
import ContextMenu from './ContextMenu';
import { createNamespacedHelpers } from 'vuex';
const { mapActions } = createNamespacedHelpers('annotations');
const { mapMutations } = createNamespacedHelpers('annotations_ui');

export default {
  components: {
    ContextMenu
  },
  props: ['annotationId',
          'hasHandle'],
  data: () => ({offsetRight: -55}),
  computed: {
    annotation() {
      return this.$store.getters['annotations/getById'](this.annotationId);
    },
    ui_state() {
      return this.$store.getters['annotations_ui/getById'](this.annotationId);
    }
  },
  methods: {
    ...mapActions(['destroy']),
    ...mapMutations(['toggleExpansion'])
  },
  mounted() {
    if(this.hasHandle) {
      // Push over annotation margin handles which land on the same line
      // TODO - consider moving this over to a vuex store
      const top = this.$el.getElementsByClassName("handle")[0].getBoundingClientRect().top;
      window.handlePositions = window.handlePositions || {};
      window.handlePositions[top] = (window.handlePositions[top] || 0) + 1;
      this.offsetRight = -25 - (30 * window.handlePositions[top]);
    }
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';
@import '../styles/handle';
@import '../styles/context-menu';

.elision {
  padding: 0 10px;
}
.toggle {
  display: inline-block;
  cursor: zoom-in;
  border: none;
  background-color: $light-gray;
  color: $light-blue;
  &::before {
    font-weight: $bold;
    content: '...';
    font-size: 19px;
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
</style>
