<template>
<div class="context-menu"
     :style="{top: offset}">
  <ul>
    <li><a @click="createApi('highlight')">Highlight</a></li>
    <li><a>Elide</a></li>
    <li><a>Replace</a></li>
    <li><a>Add link</a></li>
    <li><a>Add note</a></li>
  </ul>
</div>
</template>

<script>
import {offsetsForRanges} from 'lib/ui/content/annotations/placement';
import Axios from '../config/axios';

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
    createApi(type, content = null) {
      Axios.post(`/resources/${this.resourceId}/annotations.json`, {
        annotation: {
          kind: type,
          content: content,
          start_paragraph: this.offsets.start.p,
          start_offset: this.offsets.start.offset,
          end_paragraph: this.offsets.end.p,
          end_offset: this.offsets.end.offset
        }
      }, { scroll: false })
        .then( response => {
          window.location.search = `annotation-id=${response.data.annotation_id}`;
        });
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
