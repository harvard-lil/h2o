<template>
<div id="the-annotator"
     data-exclude-from-offset-calcs="true">
  <SideMenu v-if="offsets"
            :style="{top: offset}">
    <li>
      <a id="create-highlight"
         @click="submit('highlight')">Highlight</a>
    </li>
    <li>
      <a id="create-elision"
         @click="submit('elide')">Elide</a>
    </li>
    <li>
      <a id="create-replacement"
         @click="insertReplacementPlaceholder">Replace</a></li>
    <li>
      <a id="create-link"
         @click="input($event, 'link')">Add link</a>
    </li>
    <li>
      <a id="create-note"
         @click="input($event, 'note')">Add note</a>
    </li>
  </SideMenu>
 <ContextMenu ref="linkMenu"
               :closeOnClick="false">
    <form @submit.prevent="submitNoteAndHighlight('link', content)"
          class="form">
      <LinkInput ref="linkInput"
                 v-model="content"/>
    </form>
  </ContextMenu>

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
import { isText } from "../libs/html_helpers.js";

import { createNamespacedHelpers } from "vuex";
const { mapActions } = createNamespacedHelpers("annotations");
import { offsetsForRanges } from "../libs/placement";

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
    content: "",
    showModal: false,
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
      const targetRect = this.ranges[1].getBoundingClientRect();

      return Math.min(Math.max(targetRect.top - wrapperRect.top, viewportTop + 20),
                      targetRect.bottom - wrapperRect.top).toString(10) + "px";
    },
    resourceId() {
      return document.querySelector("header.casebook").dataset.resourceId
    },
    offsets() {
      return offsetsForRanges(this.ranges);
    },
  },
  methods: {
    ...mapActions(["create", "createAndUpdate"]),

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
      this.$refs.linkMenu.close();
      this.$refs.noteMenu.close();
    },

    submit(kind, content = null) {
      this.create({
        kind: kind,
        content: content,
        resource_id: this.resourceId,
        ...this.offsets
      }).catch(e => {
        this.showModal = true;
      });

      this.close();
    },

    submitNoteAndHighlight(kind, content = null){
      let id = this.$refs[`${kind}Menu`].$tempId;
      let annotation = this.$store.getters['annotations/getById'](id);

      this.createAndUpdate(
        {obj: annotation, vals: {content: content}}
      );

      this.$refs[`${kind}Menu`].$tempId = null;
      this.close();
    },

    insertReplacementPlaceholder() {
      this.$store.commit('annotations/append', [{
        id: this.tempId(),
        content: "",
        kind: "replace",
        resource_id: this.resourceId,
        ...this.offsets
      }]);

      this.close();
    },

    input(e, kind) {
      let id = this.tempId();

      this.$store.commit('annotations/append', [{
        id: id,
        content: "",
        kind: kind,
        resource_id: this.resourceId,
        ...this.offsets
      }]);
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
