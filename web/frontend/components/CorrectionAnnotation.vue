<template>
<span class="correction"
      :class="{head: isHead, tail: addTailClass}">
  <template v-if="isHead">
    <span v-if="!isEditable">{{content}}</span>
    <span v-else
          ref="correctionText"
          class="correction-text"
          data-exclude-from-offset-calcs="true"
          @blur="revert"
          @keydown.enter.prevent="submit"
          @keyup.esc="$event.target.blur"
          v-contenteditable:content="true"></span>
  </template>
  <!-- Use v-show rather than v-if here so that
       the text is included in offset calculations -->
  <span v-show="uiState.expanded" class="selected-text"><slot></slot></span>
  <span v-if="isTail && uiState.expanded"
        data-exclude-from-offset-calcs="true"
        class="sr-only">(end of replaced text)</span>
  <AnnotationHandle v-if="hasHandle"
                    :ui-state="uiState">
    <li>
      <a @click="toggleExpansion(uiState)">
        <template v-if="uiState.expanded">Hide</template>
        <template v-else>Reveal</template>
        original text
      </a>
    </li>
    <li>
      <a @click="destroy(annotation)">Remove correction</a>
    </li>
  </AnnotationHandle>
  <SideMenu v-if="isHead && isModified">
    <!-- Use mousedown to prevent correctionText from blurring too soon -->
    <li><a @mousedown.prevent="submit">Save</a></li>
    <li><a @mousedown.prevent="$refs.correctionText.blur">Cancel</a></li>
  </SideMenu>
</span>
</template>

<script>
import AnnotationBase from "./AnnotationBase";
import SideMenu from "./SideMenu";

import { createNamespacedHelpers } from "vuex";
const { mapActions } = createNamespacedHelpers("annotations");
const mapUIActions = createNamespacedHelpers("annotations_ui").mapActions;

export default {
  extends: AnnotationBase,
  components: {
    SideMenu
  },
  data: () => ({
    expandedDefault: false,
    newVals: {content: ""}
  }),
  computed: {
    content: {
      get() {
        return this.newVals.content || this.annotation.content
      },
      set(value) {
        this.newVals.content = value;
      }
    },
    isModified() {
      // if it's a new annotation or the content has been changed
      return this.isNew || this.content != this.annotation.content;
    },
    addTailClass() {
      return (this.isTail && this.uiState.expanded) ||
             (this.isHead && !this.uiState.expanded);
    }
  },
  methods: {
    ...mapUIActions(["toggleExpansion"]),
    ...mapActions(["createAndUpdate",
                   "update"]),

    submit() {
      if(this.isModified && this.content){
        // Work around FirefoxDevEdition bug that isn't properly populating event.target.innerText reliably
        this.newVals.content = this.$refs.correctionText.innerText;
        this[this.isNew ? "createAndUpdate" : "update"](
          {obj: this.annotation, vals: this.newVals}
        );
      } else {
        this.$refs.correctionText.blur();
      }
    },
    revert() {
      if(this.isNew) {
        this.$store.commit('annotations/destroy', this.annotation);
        this.$store.commit('annotations_ui/destroy', this.uiState);
      } else if(this.isModified) {
        this.newVals.content = this.annotation.content;
      }
    }
  },
  mounted() {
    // If we've inserted a placeholder annotation so that we can edit
    // and save a new correction, focus it once mounted.
    if(this.isNew &&
       this.$refs.correctionText) {
      this.$refs.correctionText.focus();
    }
  },
  updated() {
    // If the component was updated but the annotation isn't modified,
    // that means we just saved the annotation and should exit editing
    if(!this.isModified &&
       this.$refs.correctionText) {
      this.$refs.correctionText.blur();
    }
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';

.head {
  margin-left: 0.25em;
}
.tail {
  margin-right: 0.25em;
}
.correction-text,
.selected-text {
  background-color: $translucent-light-gray;
  padding: 0.35em;
}
.selected-text {
  display: inline;
  color: #555;
  border-radius: 3px;
}  
.correction-text {
}
.correction-text:empty::before {
  content: 'Enter correction text';
  color: $dark-gray;
}
.active .correction-text:empty::before {
  content: ' ';
}
</style>
