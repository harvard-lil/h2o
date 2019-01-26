<template>
<div class="context-menu side-menu">
  <ul class="menu-items">
    <slot></slot>
  </ul>
</div>
</template>

<script>
export default {
}
</script>

<style lang="scss" scoped>
@import "../styles/vars-and-mixins";

.side-menu {
  position: absolute;
  right: 0;
  font-style: normal;
}
.menu-items {
  position: absolute;
  left: 20px;
}
</style>
