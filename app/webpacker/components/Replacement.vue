<template>
<span class="replacement">
  <template v-if="hasHandle">
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
    <AnnotationExpansionToggle :ui-state="uiState"/>
  </template><!--
  whitespace affects offset counts so using this comment for code formatting
--><span v-show="uiState.expanded" class="selected-text"><slot></slot></span>
  <span v-if="!uiState.expanded"
        class="text"
        data-exclude-from-offset-calcs="true"
        contenteditable="true">{{annotation.content}}</span>
</span>
</template>

<script>
import Annotation from './Annotation';
import AnnotationExpansionToggle from './AnnotationExpansionToggle';
import { createNamespacedHelpers } from 'vuex';
const { mapMutations } = createNamespacedHelpers('annotations_ui');

export default {
  extends: Annotation,
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

.replacement {
  margin: 0 6px;
  padding: 0 6px;
}
.toggle {
  &::before {
    content: '';
  }
}
.selected-text {
  padding: 7px;
  display: inline;
  color: #555;
  border-radius: 3px;
  background-color: $light-gray;
}  
.text {
  pointer-events: none;
}
.text:empty::before {
  content: 'Enter replacement text';
  color: $dark-gray;
  pointer-events: none;
}
.active .text:empty::before {
  content: ' ';
  pointer-events: none;
}
</style>
