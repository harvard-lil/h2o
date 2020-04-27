<template>
<span class="replacement"
      :class="{head: isHead, tail: addTailClass}">
  <template v-if="isHead">
    <AnnotationExpansionToggle v-if="!isEditable || uiState.expanded"
                               :annotation="annotation">
      <template v-slot:collapsed>{{content}}</template>
    </AnnotationExpansionToggle>
    <span v-else
          ref="replacementText"
          class="replacement-text"
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
      <a @click="destroy(annotation)">Remove replacement</a>
    </li>
  </AnnotationHandle>
  <SideMenu v-if="isHead && isModified">
    <!-- Use mousedown to prevent replacementText from blurring too soon -->
    <li><a @mousedown.prevent="submit">Save</a></li>
    <li><a @mousedown.prevent="$refs.replacementText.blur">Cancel</a></li>
  </SideMenu>
</span>
</template>

<script>
import AnnotationBase from "./AnnotationBase";
import AnnotationExpansionToggle from "./AnnotationExpansionToggle";
import SideMenu from "./SideMenu";

import { createNamespacedHelpers } from "vuex";
const { mapActions } = createNamespacedHelpers("annotations");
const mapUIActions = createNamespacedHelpers("annotations_ui").mapActions;

export default {
  extends: AnnotationBase,
  components: {
    SideMenu,
    AnnotationExpansionToggle
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
        this.newVals.content = this.$refs.replacementText.innerText;
        this[this.isNew ? "createAndUpdate" : "update"](
          {obj: this.annotation, vals: this.newVals}
        );
      } else {
        this.$refs.replacementText.blur();
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
    // and save a new replacement, focus it once mounted.
    if(this.isNew &&
       this.$refs.replacementText) {
      this.$refs.replacementText.focus();
    }
  },
  updated() {
    // If the component was updated but the annotation isn't modified,
    // that means we just saved the annotation and should exit editing
    if(!this.isModified &&
       this.$refs.replacementText) {
      this.$refs.replacementText.blur();
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
.replacement-text,
.selected-text {
  background-color: $translucent-light-gray;
  padding: 0.35em;
}
.selected-text {
  display: inline;
  color: #555;
  border-radius: 3px;
}  
.replacement-text {
  color: $light-blue;
}
.replacement-text:empty::before {
  content: 'Enter replacement text';
  color: $dark-gray;
}
.active .replacement-text:empty::before {
  content: ' ';
}
</style>
