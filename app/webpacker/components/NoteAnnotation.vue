<template>
<span class="note">
  <a class="selected-text"
     :href="`#${annotation.id}-content`"
     :id="isHead ? `${annotation.id}-head` : ''"
     @click.prevent="handleClick"><slot></slot></a>
  <AnnotationHandle v-if="hasHandle"
                    :ui-state="uiState">
    <li>
      <a @click="destroy(annotation)">Remove note</a>
    </li>
  </AnnotationHandle>
  <template v-if="isHead">
    <span v-show="uiState.expanded"
          class="note-content-wrapper"
          data-exclude-from-offset-calcs="true">
      <a class="note-icon"
         :href="`#${annotation.id}-head`"
         @click.prevent="handleClick">
        <i class="fas fa-paperclip"></i>
      </a>
      <span :id="`${annotation.id}-content`"
            tabindex="0"
            class="note-content">
        {{annotation.content}}
      </span>
    </span>
  </template>
</span>
</template>

<script>
import AnnotationBase from './AnnotationBase';
import { createNamespacedHelpers } from 'vuex';
const { mapActions } = createNamespacedHelpers('annotations_ui');

export default {
  extends: AnnotationBase,
  methods: {
    ...mapActions(['toggleExpansion']),

    handleClick(e) {
      // Setting this focus for accessibility is at odds with the expansion toggle
      // Waiting for a decision for how to proceed here:
      // https://github.com/harvard-lil/h2o/issues/654#issuecomment-461081248
      document.getElementById(e.currentTarget.getAttribute("href").slice(1)).focus({preventScroll: true});
      this.toggleExpansion(this.uiState);
    }
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';

/* Counteract bootstrap style */
a:active {
  border-color: transparent;
}

.selected-text {
  color: inherit;
  /* Bootstrap's normalize uses !important so we must too */
  text-decoration: $light-blue underline !important;
}

.note-content-wrapper {
  @include square(0);
  position: absolute;
  right: 0;
  overflow: visible;
  display: block;
  margin: 33px 10px 0 0;

  /* counteract styles that might come from the enclosing section */
  font-style: normal;
  text-align: left;
}
.note-icon {
  position: absolute;
  transform: translate(218%, -116%) rotate(180deg);
  z-index: 1;
  font-size: 17px;
  color: $black;
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
</style>
