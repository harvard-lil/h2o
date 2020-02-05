<template>
<span class="elision">
  <AnnotationExpansionToggle v-if="isHead"
                             :annotation="annotation"
                             aria-label="elided text"/>
  <!-- Use v-show rather than v-if here so that
       the text is included in offset calculations -->
  <span v-show="uiState.expanded"
        class="selected-text"><slot></slot></span>
  <span v-if="isTail && uiState.expanded"
        data-exclude-from-offset-calcs="true"
        class="sr-only">(end of elided text)</span>
  <AnnotationHandle v-if="hasHandle"
                    :ui-state="uiState">
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
</span>
</template>

<script>
import AnnotationBase from './AnnotationBase';
import AnnotationExpansionToggle from './AnnotationExpansionToggle';
import { createNamespacedHelpers } from 'vuex';
const { mapActions } = createNamespacedHelpers('annotations_ui');

export default {
  extends: AnnotationBase,
  components: {
    AnnotationExpansionToggle
  },
  data: () => ({
    expandedDefault: false
  }),
  methods: {
    ...mapActions(['toggleExpansion'])
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';

.case-text {
    > :not(section), > section.casebody h4, > section.casebody p, > section.casebody blockquote {
        &.fully-elided {
            span.selected-text:before {
                content: counter(index);
                user-select: none;
                @include sans-serif($regular, 12px, 12px);
                position: fixed;
                width: 100px;
                left: -92px;
                text-align: right;
                line-height: 30px;
                color: $light-blue;
            }
        }
    }
}

.selected-text {
  padding: 0.35em;
  display: inline;
  color: #555;
  background-color: $translucent-light-gray;
}
</style>
