<template>
<span class="replacement"
      :class="{head: isHead, tail: isTail || (isHead && !uiState.expanded)}"
      v-if="isHead || uiState.expanded">
  <template v-if="isHead">
    <AnnotationHandle>
      <li>
        <a @click="toggleExpansion(uiState)">
          <template v-if="uiState.expanded">Hide</template>
          <template v-else>Reveal</template>
          original text
        </a>
      </li>
      <li>
        <a @click="destroy(annotation)">Remove elision</a>
      </li>
    </AnnotationHandle>
    <AnnotationExpansionToggle :ui-state="uiState"
                               v-if="uiState.expanded"/>
    <span v-if="!uiState.expanded"
          class="replacement-text"
          data-exclude-from-offset-calcs="true"
          v-contenteditable:content="true"></span>
    <div v-if="modified"
         id="edit-replacement-menu"
         class="context-menu">
      <ul class="menu-items">
        <li><a @click="submitUpdate">Save</a></li>
        <li><a @click="revert">Cancel</a></li>
      </ul>
    </div>
  </template>
  <!-- Use v-show rather than v-if here so that 
       the text is included in offset calculations -->
  <span v-show="uiState.expanded" class="selected-text"><slot></slot></span>
</span>
</template>

<script>
import AnnotationBase from './AnnotationBase';
import AnnotationExpansionToggle from './AnnotationExpansionToggle';
import { createNamespacedHelpers } from 'vuex';
const { mapActions } = createNamespacedHelpers("annotations");
const { mapMutations } = createNamespacedHelpers('annotations_ui');

export default {
  extends: AnnotationBase,
  components: {
    AnnotationExpansionToggle
  },
  data: () => ({
    newVals: {content: null}
  }),
  computed: {
    content: {
      get() {
        return this.newVals.content === null
          ? this.annotation.content
          : this.newVals.content;
      },
      set(value) {
        this.newVals.content = value;
      }
    },
    modified() {
      return this.content != this.annotation.content;
    }
  },
  methods: {
    ...mapMutations(['toggleExpansion']),
    ...mapActions(["update"]),
    revert() {
      return this.newVals.content = this.annotation.content;
    },
    submitUpdate() {
      this.update({obj: this.annotation, vals: this.newVals});
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
  background-color: $light-gray;
  padding: 0.4em;
}
.selected-text {
  display: inline;
  color: #555;
  border-radius: 3px;
}  
.replacement-text {
  color: $light-blue;
  /* pointer-events: none; */
}
.replacement-text:empty::before {
  content: 'Enter replacement text';
  color: $dark-gray;
  /* pointer-events: none; */
}
.active .replacement-text:empty::before {
  content: ' ';
  /* pointer-events: none; */
}
#edit-replacement-menu {
  position: absolute;
  right: 0;
  .menu-items {
    position: absolute;
    left: 20px;
  }
}
</style>
