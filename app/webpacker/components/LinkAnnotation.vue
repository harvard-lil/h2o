<template>
<span class="link">
  <template v-if="isHead"
            data-exclude-from-offset-calcs="true">
    <AnnotationHandle>
      <li>
        <a @click.prevent="$refs.editMenu.open">Edit link</a>
      </li>
      <li>
        <a @click="destroy(annotation)">Remove link</a>
      </li>
    </AnnotationHandle>
    <ContextMenu ref="editMenu" :closeOnClick="false">
      <form @submit.prevent="submitUpdate">
        <LinkInput v-model="content"/>
      </form>
    </ContextMenu>
  </template>
  <a :href="annotation.content" target="_blank" class="selected-text"><slot></slot></a>
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
</style>
