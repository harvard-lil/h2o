<template>
<div class="context-menu"
     :style="{top: offset}">
  <ul>
    <li><a>Highlight</a></li>
    <li><a>Elide</a></li>
    <li><a>Replace</a></li>
    <li><a>Add link</a></li>
    <li><a>Add note</a></li>
  </ul>
</div>
</template>

<script>
export default {
  props: {
    selection: {type: Array}
  },
  computed: {
    offset() {
      const wrapperRect = this.$parent.$el.getBoundingClientRect();
      const viewportTop = window.scrollY - (wrapperRect.top + window.scrollY);
      const targetRect = this.selection[0].getRangeAt(this.selection[0].rangeCount-1).getBoundingClientRect();

      return Math.min(Math.max(targetRect.top - wrapperRect.top, viewportTop + 20),
                      targetRect.bottom - wrapperRect.top).toString(10) + "px";
    }
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';

.context-menu {
  position: absolute;
  right: 0;
}
ul {
  position: absolute;
  left: 20px;
}
</style>
