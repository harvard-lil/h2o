<template>
<span class="link">
  <a :href="annotation.content" target="_blank" class="selected-text"><slot></slot></a>
  <template v-if="hasHandle">
    <AnnotationHandle :ui-state="uiState">
      <li>
        <a @click.prevent="$refs.editMenu.open">Edit link</a>
      </li>
      <li>
        <a @click="destroy(annotation)">Remove link</a>
      </li>
    </AnnotationHandle>
    <ContextMenu ref="editMenu"
                 data-exclude-from-offset-calcs="true"
                 :closeOnClick="false">
      <form @submit.prevent="submitUpdate">
        <LinkInput v-model="content"/>
      </form>
    </ContextMenu>
  </template>
</span>
</template>

<script>
import AnnotationBase from "./AnnotationBase";
import { createNamespacedHelpers } from "vuex";
const { mapActions } = createNamespacedHelpers("annotations");

import ContextMenu from "./ContextMenu";
import LinkInput from "./LinkInput";

export default {
  extends: AnnotationBase,
  components: {
    ContextMenu,
    LinkInput
  },
  data: () => ({
    newVals: {content: null}
  }),
  computed: {
    content: {
      get() {
        return this.newVals.content === null
          ? this.annotation.content
          : this.newVals.content;
      },
      set(value) {
        this.newVals.content = value;
      }
    }
  },
  methods: {
    ...mapActions(["update"]),
    submitUpdate() {
      this.update({obj: this.annotation, vals: this.newVals});
      this.$refs.editMenu.close();
    }
  }
}
</script>

<style lang="scss" scoped>
a[target="_blank"] {
  background: url(../images/external-link-icon.svg) center right no-repeat;
  background-size: 0.55em 0.55em;
  padding-right: 0.7em;
  margin-right: 0.1em;
}
</style>
