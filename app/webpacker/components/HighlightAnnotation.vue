<template>
<span class="highlight">
  <AnnotationHandle v-if="hasHandle">
    <li>
      <a @click="destroy(annotation)">Remove highlight</a>
    </li>
  </AnnotationHandle>
  <span tabindex="-1" class="selected-text"><slot></slot></span>
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
  box-shadow: -1px 0 0 $highlight, 1px 0 0 $highlight;
  padding: 1rem 0 0.5rem; /* TODO fix this for h2 highlights */
}
</style>
