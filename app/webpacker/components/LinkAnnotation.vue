<template>
<span class="link">
  <AnnotationHandle v-if="hasHandle">
    <li>
      <a @click="destroy(annotation)">Remove link</a>
    </li>
  </AnnotationHandle><!--
  whitespace affects offset counts; this comment is for code formatting
--><a :href="annotation.content" target="_blank" class="selected-text"><slot></slot></a>
</span>
</template>

<script>
import Annotation from './Annotation';

export default {
  extends: Annotation
}
</script>

<style lang="scss" scoped>
</style>
