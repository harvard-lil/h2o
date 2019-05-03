<template>
<div id="the-annotator"
     data-exclude-from-offset-calcs="true">
  <SideMenu v-if="offsets"
            :style="{top: topDistance}">
    <li>
      <a id="create-highlight"
         @click="input($event, 'highlight')">Highlight</a>
    </li>
    <li>
      <a id="create-elision"
         @click="input($event, 'elide')">Elide</a>
    </li>
    <li>
      <a id="create-replacement"
         @click="input($event, 'replace')">Replace</a></li>
    <li>
      <a id="create-link"
         @click="input($event, 'link')">Add link</a>
    </li>
    <li>
      <a id="create-note"
         @click="input($event, 'note')">Add note</a>
    </li>
  </SideMenu>

  <Modal v-if="showModal"
            @close="showModal = false">
    <template slot="title">Error</template>
    <template slot="body">
      <p>An error occurred while trying to save your annotation. Please try again.</p>
      <button class="modal-button"
              @click="showModal = false">Dismiss</button>
    </template>
  </Modal>
</div>
</template>

<script>
import { isText,
         getClosestElement } from "../libs/html_helpers.js";

import { createNamespacedHelpers } from "vuex";
const { mapActions } = createNamespacedHelpers("annotations");

import SideMenu from "./SideMenu";
import Modal from "./Modal";
import ContextMenu from "./ContextMenu";
import LinkInput from "./LinkInput";

export default {
  components: {
    SideMenu,
    Modal,
    ContextMenu,
    LinkInput
  },
  data: () => ({
    ranges: null,
    content: null,
    showModal: false,
  }),
  watch: {
    ranges() {
      this.content = "";
    }
  },
  computed: {
    topDistance() {
      const wrapperRect = this.$parent.$el.getBoundingClientRect();
      const viewportTop = window.scrollY - (wrapperRect.top + window.scrollY);
      const targetRect = this.ranges[1].getBoundingClientRect();

      return Math.min(Math.max(targetRect.top - wrapperRect.top, viewportTop + 20),
                      targetRect.bottom - wrapperRect.top).toString(10) + "px";
    },
    resourceId() {
      return document.querySelector("header.casebook").dataset.resourceId
    },
    hasValidRanges() {
      return this.ranges &&
        !this.ranges[0].collapsed &&
        // Ensure that the selection is within the case-text wrapper
      getClosestElement(this.ranges[0].commonAncestorContainer).closest(".case-text")
    },
    resourceBody() {
      return document.querySelector(".case-text");
    },
    offsets() {
      return !this.hasValidRanges ? null :
        {start_offset: this.offsetInBody(this.ranges[0].startContainer,
                                         this.ranges[0].startOffset),
         end_offset: this.offsetInBody(this.ranges[1].endContainer,
                                       this.ranges[1].endOffset)};
    },
  },
  methods: {
    ...mapActions(["create"]),

    offsetInBody(targetNode, offset) {
      const walker = document.createTreeWalker(
        this.resourceBody,
        NodeFilter.SHOW_TEXT,
        {acceptNode: (node) => !node.parentNode.closest("[data-exclude-from-offset-calcs='true']")}
      );
      for (let node = walker.nextNode();
           (isText(targetNode) && node !== targetNode) || !targetNode.contains(node);
           node = walker.nextNode()) {
        offset += node.length;
      }
      return offset;
    },

    tempId() {
      return Math.floor(Math.random() * Math.floor(10000000)) * -1;
    },

    selectionchange(e, sel) {
      if(sel &&
         (isText(sel.anchorNode)
          ? sel.anchorNode.parentNode
          : sel.anchorNode).closest("[data-exclude-from-offset-calcs='true']")) return;

      this.ranges =
        (!sel || sel.type != "Range")
        ? null
        : [sel.getRangeAt(0),
           sel.getRangeAt(sel.rangeCount-1)];
    },

    close() {
      document.getSelection().empty();
      this.ranges = null;
    },

    input(e, kind) {
      let id = this.tempId();

      this.$store.commit('annotations/append', [{
        id: id,
        content: this.content,
        kind: kind,
        resource_id: this.resourceId,
        ...this.offsets
      }]);

      this.close();
    },
  }
}
</script>

<style lang="scss" scoped>
@import "../styles/vars-and-mixins";

#the-annotator {
  user-select: none;
}
.form {
  display: flex;
  flex-direction: column;
}
.button {
  margin-top: 1em;
}
</style>
