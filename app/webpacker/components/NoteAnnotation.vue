<template>
<span class="note">
  <template v-if="isHead">
    <AnnotationHandle :ui-state="uiState">
      <li>
        <a @click="destroy(annotation)">Remove note</a>
      </li>
    </AnnotationHandle>
    <span v-if="uiState.expanded"
          class="note-content-wrapper"
          data-exclude-from-offset-calcs="true">
      <span class="note-icon"
            @click="toggleExpansion(uiState)">
        <i class="fas fa-paperclip"></i>
      </span>
      <span class="note-content">
        {{annotation.content}}
      </span>
    </span>
  </template>
  <span tabindex="-1"
        class="selected-text"
        @click="toggleExpansion(uiState)"><slot></slot></span>
</span>
</template>

<script>
import AnnotationBase from './AnnotationBase';
import { createNamespacedHelpers } from 'vuex';
const { mapActions } = createNamespacedHelpers('annotations_ui');

export default {
  extends: AnnotationBase,
  methods: {
    ...mapActions(['toggleExpansion'])
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';

.selected-text {
  text-decoration: $light-blue underline;
  outline: none;
  cursor: pointer;
}

.note-content-wrapper {
  @include square(0);
  position: absolute;
  right: 0;
  overflow: visible;
  display: block;
  margin: 33px 10px 0 0;

  /* TODO is this needed? */
  &.revealed {
    display: none;
  }
}
.note-icon {
  position: absolute;
  transform: translate(218%, -116%) rotate(180deg);
  z-index: 1;
  font-size: 17px;
}
.note-content {
  @include sans-serif($regular, 14px, 20px);
  display: block;
  width: 200px;
  padding: 10px;
  position: relative;
  top: -20px;
  background-color: $white;
  color: $black;
  margin: 0 20px;
}

.note-icon {
  color: $black;
  cursor: pointer;
}
</style>
