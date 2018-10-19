<template>
  <span class="handle" v-bind:style="{right: offsetRight + 'px'}" @click="clickHandler">
    <span class="button">✎</span>
  </span>
</template>

<script>
export default {
  props: ['annotationId'],
  data: () => ({
    offsetRight: -55
  }),
  methods: {
    clickHandler() {
      alert(this.$store.getters['annotations/getById'](this.annotationId).kind);
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
