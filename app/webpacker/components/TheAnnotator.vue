<template>
<div class="context-menu"
     :style="{top: offset}">
  <ul>
    <li><a @click="submit('highlight')">Highlight</a></li>
    <li><a @click="submit('elide')">Elide</a></li>
    <li><a>Replace</a></li>
    <li><a>Add link</a></li>
    <li><a>Add note</a></li>
  </ul>
</div>
</template>

<script>
import { createNamespacedHelpers } from 'vuex';
const { mapActions } = createNamespacedHelpers('annotations');
import {offsetsForRanges} from 'lib/ui/content/annotations/placement';

export default {
  props: {
    ranges: {type: Object}
  },
  computed: {
    offset() {
      const wrapperRect = this.$parent.$el.getBoundingClientRect();
      const viewportTop = window.scrollY - (wrapperRect.top + window.scrollY);
      const targetRect = this.ranges.last.getBoundingClientRect();

      return Math.min(Math.max(targetRect.top - wrapperRect.top, viewportTop + 20),
                      targetRect.bottom - wrapperRect.top).toString(10) + "px";
    },
    resourceId() {
      return document.querySelector('header.casebook').dataset.resourceId
    },
    offsets() {
      return offsetsForRanges(this.ranges);
    }
  },
  methods: {
    ...mapActions(['create']),

    submit(type, content = null) {
      this.create({
        kind: type,
        content: content,
        resource_id: this.resourceId,
        ...this.offsets
      });
      this.$emit("clear-ranges");
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
