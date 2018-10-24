<template>
  <div>
    <button aria-label="Edit annotation"
            v-bind:style="{right: offsetRight + 'px'}"
            @click.prevent="$refs.mainMenu.open">✎</button>

    <ContextMenu ref="mainMenu">
      <ul>
        <li v-if="annotation.kind == 'replace'">
          <a @click="reveal">Reveal original text</a>
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
        <input name="content" type="url" placeholder="Url to link to..." v-model="content"/>
      </form>
    </ContextMenu>
  </div>
</template>

<script>
import ContextMenu from './ContextMenu';
import { createNamespacedHelpers } from 'vuex';
import { toggleElisionVisibility } from 'lib/ui/content/annotations/elide';
const { mapActions } = createNamespacedHelpers('annotations');

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
    submitUpdate() {
      this.update({obj: this.annotation, vals: this.newVals});
      this.$refs.linkMenu.close();
    },
    reveal() {
      const elisions = document.querySelectorAll(`.annotate.replaced[data-annotation-id="${this.annotation.id}"]`);
      const button = document.querySelector(`.annotate.replacement[data-annotation-id="${this.annotation.id}"]`);
      toggleElisionVisibility(this.annotation.id, 'replace', button, elisions);
    }
  },
  mounted() {
    // Push over annotation margin handles which land on the same line
    const top = this.$el.getBoundingClientRect().top;
    window.handlePositions = window.handlePositions || {};
    window.handlePositions[top] = (window.handlePositions[top] || 0) + 1
    this.offsetRight = -25 - (30 * window.handlePositions[top]);
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';

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

.context-menu {
  ul li {
    padding: 0;
  }
  a {
    display: block;
  }
  a, form {
    padding: 10px 15px;
  }
}
</style>
