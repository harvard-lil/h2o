<template>
<span class="replacement"
      :class="{head: isHead, tail: isTail || (isHead && !uiState.expanded)}"
      v-if="isHead || uiState.expanded">
  <template v-if="isHead">
    <template v-if="annotation.id">
      <AnnotationHandle :ui-state="uiState">
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
      <AnnotationExpansionToggle :ui-state="uiState"
                                 v-if="uiState.expanded"/>
    </template>
    <span v-if="!uiState.expanded"
          ref="replacementText"
          class="replacement-text"
          data-exclude-from-offset-calcs="true"
          @blur="revert"
          @keydown.enter.prevent="submit"
          @keyup.esc="$event.target.blur"
          v-contenteditable:content="editable"></span>
    <SideMenu v-if="isModified">
      <!-- Use mousedown to prevent replacementText from blurring too soon -->
      <li><a @mousedown.prevent="submit">Save</a></li>
      <li><a @mousedown.prevent="$refs.replacementText.blur">Cancel</a></li>
    </SideMenu>
  </template>
  <!-- Use v-show rather than v-if here so that 
       the text is included in offset calculations -->
  <span v-show="uiState.expanded" class="selected-text"><slot></slot></span>
</span>
</template>

<script>
import AnnotationBase from "./AnnotationBase";
import AnnotationExpansionToggle from "./AnnotationExpansionToggle";
import SideMenu from "./SideMenu";

import { createNamespacedHelpers } from "vuex";
const { mapActions } = createNamespacedHelpers("annotations");
const { mapMutations } = createNamespacedHelpers("annotations_ui");

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
    editable() {
      return this.$store.getters["resources_ui/getEditability"]
    },
    isModified() {
      // if it's a new annotation or the content has been changed
      return this.isNew || this.content != this.annotation.content;
    }
  },
  methods: {
    ...mapMutations(["toggleExpansion"]),
    ...mapActions(["createAndUpdate", "update"]),
    submit() {
      if(this.isModified){
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
    if(this.isNew) {
      this.$refs.replacementText.focus();
    }
  },
  updated() {
    if(!this.isModified) {
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
