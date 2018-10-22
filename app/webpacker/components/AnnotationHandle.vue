<template>
  <div>
    <span class="handle" v-bind:style="{right: offsetRight + 'px'}" @click.prevent="$refs.menu.open">
      <span class="button">✎</span>
    </span>
    <VueContext ref="menu" class="menu">
      <ul>
        <li v-if="annotation.kind == 'replace'">
          <a @click="reveal">Reveal original text</a>
        </li>
        <li v-else-if="annotation.kind == 'link'">
          <a @click="editLink">Edit link</a>
        </li>
        <li>
          <a @click="destroy">Remove {{engName}}</a>
        </li>
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
    destroy() {
      this.$http
        .delete(this.path)
        .then(resp => window.location.reload());
      return false;
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

.v-context.menu {
  width: auto;
  border: 1px solid $black;
  box-shadow: none;
  &:focus { outline: none; }
  ul { padding: 0; }
  li {
    padding: 10px 15px;
    @include sans-serif($regular, 12px, 14px);
    background-color: $white;
    &:hover { background-color: $highlight; }
  }
  a { white-space: nowrap; }
}
</style>
