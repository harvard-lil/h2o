<template>
  <svg height="20" width="32" v-bind:class="{open: !collapsed, collapsed:collapsed}">
    <polygon points="6,0 20,10 6,18" />
  </svg>
</template>

<script>
export default {
  name: "collapse-triangle",
  props: ["collapsed"]
};
</script>

<style lang="scss" scoped>
@import "../styles/vars-and-mixins";
polygon {
  fill: $light-gray;
  stroke: $black;
  stroke-width: 1;
}
polygon:hover {
  stroke-width: 2;
  stroke: $white;
}
.open {
  transition: transform 0.25s;
  transform: rotate(90deg);
  transform-origin: 30% 50%;
}
.collapsed {
  transition: transform 0.25s;
  transform: rotate(0deg);
  transform-origin: 30% 50%;
}
</style>
