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
                 :closeOnClick="false"
                 class="edit-menu">
      <form @submit.prevent="submitUpdate">
        <LinkInput v-model="content"/>
      </form>
    </ContextMenu>
  </template>
  <template v-if="isNew && isHead">
    <div class="link-content-wrapper"
    tabindex="-1">
      <form @submit.prevent="submit('link', content)"
            class="form link-form"
            :id= "`${annotation.id}`"
            ref="linkForm"
            tabindex="0"
            @focusout="focusOut"
            >
          <input id="link-input"
                type="url"
                required="true"
                pattern="\w+://\w+.*"
                placeholder="Url to link to..."
                ref="linkInput"
                v-model="content"
                tabindex="0"/>
      </form>
    </div>
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
  props: ["value"],
  data: () => ({
    newVals: {content: null},
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
    ...mapActions(["update", "createAndUpdate"]),
    submitUpdate() {
      this.update({obj: this.annotation, vals: this.newVals});
      this.$refs.editMenu.close();
    },
    submit(kind, content = null){
      this.createAndUpdate(
        {obj: this.annotation, vals: this.newVals}
      );
    },
    focusOut(e){
      if(Math.sign(this.annotation.id) === -1){
        this.$store.commit('annotations/destroy', this.annotation);
        this.$store.commit('annotations_ui/destroy', this.uiState);
      }
    }
  },
  mounted() {
    this.$nextTick(function () {
      if (Math.sign(this.annotation.id) == -1){
        this.$refs.linkInput.focus();
      }
    })
  },
}
</script>

<style lang="scss" scoped>
@import 'vars-and-mixins';
a[target="_blank"] {
  background: url(~static/images/external-link-icon.svg) center right no-repeat;
  background-size: 0.55em 0.55em;
  padding-right: 0.7em;
  margin-right: 0.1em;
}
.link-content-wrapper {
  @include sans-serif($regular, 12px, 14px);
  @include square(0);
  position: absolute;
  right: 0;
  overflow: visible;
  display: block;
  z-index: 999;

  /* counteract styles that might come from the enclosing section */
  font-style: normal;
  text-align: left;

  .form {
    display: flex;
    flex-direction: column;
    border: 1px solid black;
    padding: 10px 15px;
    width: 200px;
    background: white;
    margin-left: 10px;
    z-index: 999;
  }
}
.edit-menu {
  margin-left: 10px;
}
</style>
