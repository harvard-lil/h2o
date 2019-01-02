<template>
<button aria-label="Edit annotation"
        v-bind:style="{right: offsetRight + 'px'}">✎</button>
</template>

<script>
export default {
  data: () => ({offsetRight: -55}),
  mounted() {
    // Push over annotation margin handles which land on the same line
    // TODO - consider moving this over to a vuex store
    const top = this.$el.getBoundingClientRect().top;
    window.handlePositions = window.handlePositions || {};
    window.handlePositions[top] = (window.handlePositions[top] || 0) + 1;
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
</style>
