<template>
<div id="the-annotator">
  <div v-if="ranges"
       id="create-annotation-menu"
       class="context-menu"
       :style="{top: offset}">
    <ul class="menu-items">
      <li><a @click="submit('highlight')">Highlight</a></li>
      <li><a @click="submit('elide')">Elide</a></li>
      <li><a @click="insertReplacementPlaceholder">Replace</a></li>
      <li><a @click="input($event, 'link')">Add link</a></li>
      <li><a @click="input($event, 'note')">Add note</a></li>
    </ul>
  </div>

  <ContextMenu ref="linkMenu"
               :closeOnClick="false">
    <form @submit.prevent="submit('link', content)"
          class="form">
      <LinkInput ref="linkInput"
                 v-model="content"/>
    </form>
  </ContextMenu>

  <ContextMenu ref="noteMenu"
               :closeOnClick="false">
    <form @submit.prevent="submit('note', content)"
          class="form">
      <textarea ref="noteInput"
                placeholder="Note text..."
                v-model="content"></textarea>
      <input type="submit"
             value="Save"
             class="button">
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
  data: () => ({
    ranges: null,
    content: ""
  }),
  watch: {
    ranges() {
      this.content = "";
    }
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
      return document.querySelector("header.casebook").dataset.resourceId
    },
    offsets() {
      return offsetsForRanges(this.ranges);
    }
  },
  methods: {
    ...mapActions(["create"]),

    selectionchange(e, sel) {
      if(sel &&
         (sel.anchorNode.tagName == "FORM" ||
          this.$el.contains(sel.anchorNode))) return;

      this.ranges =
        (!sel || sel.type != "Range")
        ? null
        : {first: sel.getRangeAt(0),
           last: sel.getRangeAt(sel.rangeCount-1)};
    },

    submit(type, content = null) {
      this.create({
        kind: type,
        content: content,
        resource_id: this.resourceId,
        ...this.offsets
      });
      // clear the selection, thereby hiding the menu
      document.getSelection().empty();
      this.$refs.linkMenu.close();
      this.$refs.noteMenu.close();
    },

    insertReplacementPlaceholder() {
      this.$store.commit('annotations/append', [{
        id: null,
        content: "",
        kind: "replace",
        resource_id: this.resourceId,
        ...this.offsets
      }]);
    },

    input(e, kind) {
      this.$refs[`${kind}Menu`].open(e);
      this.$nextTick(
        () =>
          (this.$refs[`${kind}Input`].$el ||
           this.$refs[`${kind}Input`]).focus()
      );
    }
  }
}
</script>

<style lang="scss" scoped>
@import "../styles/vars-and-mixins";

#the-annotator {
  user-select: none;
}
#create-annotation-menu {
  position: absolute;
  right: 0;
  .menu-items {
    position: absolute;
    left: 20px;
  }
}

.form {
  display: flex;
  flex-direction: column;
}
.button {
  margin-top: 1em;
}
</style>
