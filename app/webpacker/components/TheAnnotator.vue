<template>
<div>
  <div id="create-annotation-menu"
       class="context-menu"
       :style="{top: offset}">
    <ul class="menu-items">
      <li><a @click="submit('highlight')">Highlight</a></li>
      <li><a @click="submit('elide')">Elide</a></li>
      <li><a @click="submit('replace', 'This is a replacement')">Replace</a></li>
      <li><a @click.prevent="$refs.linkMenu.open">Add link</a></li>
      <li><a @click="submit('note', 'This is a note')">Add note</a></li>
    </ul>
  </div>

  <ContextMenu ref="linkMenu" :closeOnClick="false">
    <form @submit.prevent="submit('link', content)">
      <LinkInput v-model="content"/>
    </form>
  </ContextMenu>
</div>
</template>

<script>
import { createNamespacedHelpers } from "vuex";
const { mapActions } = createNamespacedHelpers("annotations");
import {offsetsForRanges} from "lib/ui/content/annotations/placement";

import ContextMenu from "./ContextMenu";
import LinkInput from "./LinkInput";

export default {
  components: {
    ContextMenu,
    LinkInput
  },
  props: {
    ranges: {type: Object}
  },
  data: () => ({
    content: ""
  }),
  computed: {
    offset() {
      const wrapperRect = this.$parent.$el.getBoundingClientRect();
      const viewportTop = window.scrollY - (wrapperRect.top + window.scrollY);
      const targetRect = this.ranges.last.getBoundingClientRect();

      return Math.min(Math.max(targetRect.top - wrapperRect.top, viewportTop + 20),
                      targetRect.bottom - wrapperRect.top).toString(10) + "px";
    },
    resourceId() {
      return document.querySelector("header.casebook").dataset.resourceId
    },
    offsets() {
      return offsetsForRanges(this.ranges);
    }
  },
  methods: {
    ...mapActions(["create"]),

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
@import "../styles/vars-and-mixins";

#create-annotation-menu {
  position: absolute;
  right: 0;
  .menu-items {
    position: absolute;
    left: 20px;
  }
}
</style>
