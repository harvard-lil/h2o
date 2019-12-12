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
  <span v-if="isHead"
        class="note-content-wrapper"
        data-exclude-from-offset-calcs="true">
    <form v-if="isNew"
          @submit.prevent="submit('note', content)"
          ref="noteForm"
          class="form note-content"
          :id= "`${annotation.id}`"
          @focusout="focusOut">
      <textarea ref="noteInput"
                id="note-textarea"
                required="true"
                placeholder="Note text..."
                @keydown.enter.prevent="$refs.noteSubmitButton.click"
                v-model="content"></textarea>
      <input ref="noteSubmitButton"
             type="submit"
             value="Save"
             id="save-note"
             class="button">
    </form>
    <template v-else>
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
    </template>
  </span>
</span>
</template>

<script>
import AnnotationBase from './AnnotationBase';
import { createNamespacedHelpers } from 'vuex';
const { mapGetters } = createNamespacedHelpers('annotations_ui');
const { mapActions } = createNamespacedHelpers("annotations");

export default {
  extends: AnnotationBase,
  props: ["tempId"],
  data: () => ({
    content: "",
  }),
  methods: {
    ...mapActions(['createAndUpdate']),

    handleClick(e) {
      document.getElementById(e.currentTarget.getAttribute("href").slice(1)).focus({preventScroll: true});
    },
    submit(kind, content = null){
      let id = this.$refs.noteForm.id;
      let annotation = this.$store.getters['annotations/getById'](parseInt(id));

      this.createAndUpdate(
        {obj: annotation, vals: {content: content}}
      );
    },
    focusOut(e){
      if (Math.sign(this.annotation.id) === -1 && e.relatedTarget == null || e.relatedTarget !== null && ["save-note", "note-textarea"].includes(e.relatedTarget.id) == false){     
        this.$store.commit('annotations/destroy', this.annotation);
        this.$store.commit('annotations_ui/destroy', this.uiState);
      }
    }
  },
  mounted() {
    this.$nextTick(function () {
      if (Math.sign(this.annotation.id) == -1){
        this.$refs.noteInput.focus()
      }
    })
  },
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
  display: block;
  width: 0;
  position: absolute;
  right: -50px;
  top: 45px;
  /* counteract styles that might come from the enclosing section */
  font-style: normal;
  text-align: left;

  .form {
    display: flex;
    flex-direction: column;
    border: 1px solid black;
    padding: 10px 15px;
    width: fit-content;
  }

  .button {
    margin-top: 1em;
  }
}
.note-icon {
  position: absolute;
  transform: rotate(180deg);
  z-index: 1;
  font-size: 17px;
  color: $black;
  top: -20px;
  left: 10px;
}
.note-content {
  @include sans-serif($regular, 14px, 20px);
  display: block;
  width: 200px;
  padding: 10px;
  background-color: $white;
  color: $black;
}
</style>
