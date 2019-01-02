<template>
<span>
  <button aria-label="Edit annotation"
          id="edit-annotation"
          v-bind:style="{right: offsetRight + 'px'}"
          @click.prevent="$refs.mainMenu.open">✎</button>
  
  <ContextMenu ref="mainMenu">
    <ul>
      <li v-if="annotation.kind == 'replace'">
        <a @click="toggleExpansion(ui_state)">
          <template v-if="ui_state.expanded">Hide</template>
          <template v-else>Reveal</template>
          original text
        </a>
      </li>
      <li v-else-if="annotation.kind == 'link'">
        <a @click.prevent="$refs.linkMenu.open">Edit link</a>
      </li>
      <li>
        <a @click="destroy(annotation)">Remove {{engName}}</a>
      </li>
    </ul>
  </ContextMenu>
  
  <ContextMenu ref="linkMenu" v-bind:closeOnClick="false">
    <form v-on:submit.prevent="submitUpdate">
      <input name="content" id="link-form" placeholder="Url to link to..." v-model="content"/>
    </form>
  </ContextMenu>
</span>
</template>

<script>
import ContextMenu from './ContextMenu';
import { createNamespacedHelpers } from 'vuex';
import { toggleElisionVisibility } from 'lib/ui/content/annotations/elide';
const { mapActions } = createNamespacedHelpers('annotations');
const { mapMutations } = createNamespacedHelpers('annotations_ui');

export default {
  components: {
    ContextMenu
  },
  props: ['annotationId'],
  data: () => ({
    offsetRight: -55,
    newVals: {}
  }),
  computed: {
    annotation() {
      return this.$store.getters['annotations/getById'](this.annotationId);
    },
    ui_state() {
      return this.$store.getters['annotations_ui/getById'](this.annotationId);
    },
    content: {
      get() {
        return this.newVals.content || this.annotation.content;
      },
      set(value) {
        this.newVals.content = value;
      }
    },
    engName() {
      return {
        highlight: 'highlighting',
        elide: 'elision',
        replace: 'replacement text'
      }[this.annotation.kind] || this.annotation.kind;
    }
  },
  methods: {
    ...mapActions(['update', 'destroy']),
    ...mapMutations(['toggleExpansion']),
    submitUpdate() {
      this.update({obj: this.annotation, vals: this.newVals});
      this.$refs.linkMenu.close();
    }
  },
  mounted() {
    // Push over annotation margin handles which land on the same line
    const top = this.$el.getElementsByTagName("button")[0].getBoundingClientRect().top;
    window.handlePositions = window.handlePositions || {};
    window.handlePositions[top] = (window.handlePositions[top] || 0) + 1
    this.offsetRight = -25 - (30 * window.handlePositions[top]);
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';
@import '../styles/context-menu';

$size: 28px;

button {
  @include square($size);
  position: absolute;
  right: 0;
  padding: 0;
  user-select: none;
  font-size: 1.65rem;
  text-align: center;
  line-height: $size;
  border-radius: $size;
  color: $light-blue;
  border: 2px solid $white;
  background: $light-gray;
}
</style>
