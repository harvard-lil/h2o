<template>
<div class="handle" v-bind:style="{right: offsetRight + 'px'}" @click.prevent="$refs.menu.open">
  <span class="button">✎</span>
  <VueContext ref="menu">
    <ul>
      <li v-if="annotation.kind == 'replace'" @click="reveal">Reveal original text</li>
      <li v-else-if="annotation.kind == 'link'" @click="editLink">Edit link</li>
      <li @click="destroy">Remove {{engName}}</li>
    </ul>
  </VueContext>
</div>
</template>

<script>
import { VueContext } from 'vue-context';

export default {
  components: {
    VueContext
  },
  props: ['annotationId'],
  data: () => ({
    offsetRight: -55
  }),
  computed: {
    annotation() {
      return this.$store.getters['annotations/getById'](this.annotationId);
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
    onClick() {
      alert(this.annotation.kind);
    },
    destroy() {
      alert("destroy!!!");
    },
    reveal() {
      alert("reveal...");
    },
    editLink() {
      alert("edit link");
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
</style>
