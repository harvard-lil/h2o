<template>
<span class="note">
  <template v-if="hasHandle">
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
  </template>
  <template v-if="isHead && !isNew">
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
  <template v-if="isNew && isHead">
      <a class="selected-text"
         :href="`#${annotation.id}-content`"
         :id="isHead ? `${annotation.id}-head` : ''"
         @click.prevent="handleClick"><slot></slot></a>
      <div class="new-note-content-wrapper">
        <form @submit.prevent="submit('note', content)"
              ref="noteForm"
              class="form note-content"
              :id= "`${annotation.id}`">
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
      </div>
  </template>
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
    ...mapGetters(['toggleExpansion']),
    ...mapActions(['createAndUpdate']),

    handleClick(e) {
      // Setting this focus for accessibility is at odds with the expansion toggle
      // Waiting for a decision for how to proceed here:
      // https://github.com/harvard-lil/h2o/issues/654#issuecomment-461081248
      document.getElementById(e.currentTarget.getAttribute("href").slice(1)).focus({preventScroll: true});
      this.toggleExpansion(this.uiState);
    },
    submit(kind, content = null){
      let id = this.$refs.noteForm.id;
      let annotation = this.$store.getters['annotations/getById'](parseInt(id));

      this.createAndUpdate(
        {obj: annotation, vals: {content: content}}
      );
    },
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

.new-note-content-wrapper {
  @include square(0);
  position: absolute;
  right: 0;
  overflow: visible;
  display: block;

  /* counteract styles that might come from the enclosing section */
  font-style: normal;
  text-align: left;

  .form {
    display: flex;
    flex-direction: column;
    border: 1px solid black;
    padding: 10px 15px;
  }

  .button {
    margin-top: 1em;
  }

  .note-content {
    width: fit-content;
  }
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
