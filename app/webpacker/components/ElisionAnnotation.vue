<template>
<span class="elision">
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
  </template>
  <span v-show="uiState.expanded" class="selected-text"><slot></slot></span>
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

.selected-text {
  padding: 7px;
  display: inline;
  color: #555;
  border-radius: 3px;
  background-color: $light-gray;
}
</style>
