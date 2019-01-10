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
          contenteditable="true">{{annotation.content}}</span>
  </template>
  <span v-if="uiState.expanded" class="selected-text"><slot></slot></span>
</span>
</template>

<script>
import AnnotationBase from './AnnotationBase';
import AnnotationExpansionToggle from './AnnotationExpansionToggle';
import { createNamespacedHelpers } from 'vuex';
const { mapMutations } = createNamespacedHelpers('annotations_ui');

export default {
  extends: AnnotationBase,
  components: {
    AnnotationExpansionToggle
  },
  methods: {
    ...mapMutations(['toggleExpansion'])
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
  padding: 0.5em;
}
.selected-text {
  display: inline;
  color: #555;
  border-radius: 3px;
}  
.replacement-text {
  color: $light-blue;
  pointer-events: none;
}
.replacement-text:empty::before {
  content: 'Enter replacement text';
  color: $dark-gray;
  pointer-events: none;
}
.active .replacement-text:empty::before {
  content: ' ';
  pointer-events: none;
}
</style>
