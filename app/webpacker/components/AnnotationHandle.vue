<template>
  <div>
    <span class="handle" v-bind:style="{right: offsetRight + 'px'}" @click.prevent="$refs.mainMenu.open">
      <span class="button">✎</span>
    </span>
    <ContextMenu ref="mainMenu">
      <ul>
        <li v-if="annotation.kind == 'replace'">
          <a @click="reveal">Reveal original text</a>
        </li>
        <li v-else-if="annotation.kind == 'link'">
          <a @click="openLinkMenu">Edit link</a>
        </li>
        <li>
          <a @click="destroy(annotation)">Remove {{engName}}</a>
        </li>
      </ul>
    </ContextMenu>
    <ContextMenu ref="linkMenu" v-bind:closeOnClick="false">
      <form v-on:submit.prevent="updateLink">
        <input name="content" type="url" placeholder="Url to link to..." v-bind:value="annotation.content"/>
      </form>
    </ContextMenu>
  </div>
</template>

<script>
import ContextMenu from './ContextMenu';
import { createNamespacedHelpers } from 'vuex';
const { mapActions } = createNamespacedHelpers('annotations');

export default {
  components: {
    ContextMenu
  },
  props: ['annotationId'],
  data: () => ({
    offsetRight: -55
  }),
  computed: {
    annotation() {
      return this.$store.getters['annotations/getById'](this.annotationId);
    },
    path() {
      return '/resources/$RESOURCE_ID/annotations/$ANNOTATION_ID'.replace('$RESOURCE_ID', this.$store.state.resource.id).replace('$ANNOTATION_ID', this.annotation.id)
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
    ...mapActions(['destroy']),
    reveal() {
      alert("reveal...");
    },
    openLinkMenu(e) {
      this.$refs.linkMenu.open(e);
      
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

.handle {
  @include square($size);
  position: absolute;
  right: 0;
  user-select: none;
}

.button {
  font-size: 1.65rem;
  text-align: center;
  line-height: $size;
  @include square($size);
  border-radius: $size;
  display: block;
  overflow: hidden;
  cursor: pointer;
  color: $light-blue;
  border: 2px solid $white;
  background: $light-gray;
}

form {
  padding: 10px 15px;
}
</style>
