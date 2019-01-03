<template>
<span class="note">
  <AnnotationHandle v-if="hasHandle">
    <li>
      <a @click="destroy(annotation)">Remove note</a>
    </li>
  </AnnotationHandle><!--
  whitespace affects offset counts; this comment is for code formatting
--><span tabindex="-1" class="selected-text"><slot></slot></span>
</span>
</template>

<script>
import Annotation from './Annotation';

export default {
  extends: Annotation
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';

.selected-text {
  text-decoration: $light-blue underline;
  outline: none;
  &:hover {
    cursor: pointer;
  }
}
</style>
