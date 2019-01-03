<template>
<span class="link">
  <template v-if="hasHandle"
            data-exclude-from-offset-calcs="true">
    <AnnotationHandle>
      <li>
        <a @click.prevent="$refs.editMenu.open">Edit link</a>
      </li>
      <li>
        <a @click="destroy(annotation)">Remove link</a>
      </li>
    </AnnotationHandle>
    <ContextMenu ref="editMenu" v-bind:closeOnClick="false">
      <form v-on:submit.prevent="submitUpdate">
        <input name="content" id="link-form" placeholder="Url to link to..." v-model="content"/>
      </form>
    </ContextMenu>
  </template><!--
  whitespace affects offset counts; this comment is for code formatting
--><a :href="annotation.content" target="_blank" class="selected-text"><slot></slot></a>
</span>
</template>

<script>
import ContextMenu from './ContextMenu';
import Annotation from './Annotation';

export default {
  extends: Annotation,
  components: {
    ContextMenu
  },
  data: () => ({
    newVals: {}
  }),
  computed: {
    content: {
      get() {
        return this.newVals.content || this.annotation.content;
      },
      set(value) {
        this.newVals.content = value;
      }
    }
  },
  methods: {
    submitUpdate() {
      this.update({obj: this.annotation, vals: this.newVals});
      this.$refs.editMenu.close();
    }
  },
}
</script>

<style lang="scss" scoped>
</style>
