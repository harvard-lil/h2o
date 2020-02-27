<template>
<span class="note">
  <a class="selected-text"
     :href="`#${annotation.id}-content`"
     :id="isHead ? `${annotation.id}-head` : ''"
     @click.prevent="handleClick"><slot></slot></a>
  <AnnotationHandle v-if="hasHandle"
                    :ui-state="uiState">
   <li>
      <a @click="editNote(annotation)">Edit Note</a>
    </li>
    <li>
      <a @click="destroy(annotation)">Remove note</a>
    </li>
  </AnnotationHandle>
  <span v-if="isHead"
        class="note-content-wrapper"
        v-bind:class="{top: isEditing}"
        data-exclude-from-offset-calcs="true">
    <form v-if="isEditing"
          @submit.prevent="submit('note', content)"
          ref="noteForm"
          class="form note-content"
          :id= "`${annotation.id}`"
          v-click-outside="dismissNote">
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
import Vue from 'vue'
import AnnotationBase from './AnnotationBase';
import vClickOutside from 'v-click-outside'
import { createNamespacedHelpers } from 'vuex';
const { _mapGetters } = createNamespacedHelpers('annotations_ui');
const { mapActions } = createNamespacedHelpers("annotations");

Vue.use(vClickOutside)

export default {
  extends: AnnotationBase,
  props: ["tempId"],
  data: () => ({
    content: "",
    isEditing: false
  }),
  methods: {
    ...mapActions(['createAndUpdate', 'update']),

    handleClick(e) {
      document.getElementById(e.currentTarget.getAttribute("href").slice(1)).focus({preventScroll: true});
    },
    editNote() {
      this.isEditing = true;
      this.content = this.annotation.content;
    },
    submit(kind, input = null){
      if (this.isNew) {
      let id = this.$refs.noteForm.id;
      let annotation = this.$store.getters['annotations/getById'](parseInt(id));

      this.createAndUpdate(
        {obj: annotation, vals: {content: input}}
      );
      } else {
        this.update({obj: this.annotation, vals:{content: input}})
        this.isEditing = false;
      }
      this.content = input;
    },
    dismissNote(){
      if (this.isNew) {
        this.$store.commit('annotations/destroy', this.annotation);
        this.$store.commit('annotations_ui/destroy', this.uiState);
      } else {
        this.isEditing = false;
      }
    }
  },
  mounted() {
    this.$nextTick(function () {
      if (Math.sign(this.annotation.id) == -1){
        this.isEditing = true;
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
  /* counteract styles that might come from the enclosing section */
  font-style: normal;
  text-align: left;
  float:right;
  clear:both;
  position:relative;
  left:60px;
  top: 40px;
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
.top {
  z-index: 10;
}
</style>
