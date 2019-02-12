<template>
<span class="highlight">
  <span class="selected-text"><slot></slot></span>
  <AnnotationHandle v-if="hasHandle"
                    :ui-state="uiState">
    <li>
      <a @click="destroy(annotation)">Remove highlight</a>
    </li>
  </AnnotationHandle>
</span>
</template>

<script>
import AnnotationBase from './AnnotationBase';

export default {
  extends: AnnotationBase
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';

.selected-text {
  background-color: $highlight;
}

/*
 * NOTE: ResourceSectionWrapper contains padding styles
 * for the highlight background.
 */
</style>
