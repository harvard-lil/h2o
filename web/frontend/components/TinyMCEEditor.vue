<template>
<textarea ref="textarea" :id="taID" :value="value" @input="$emit('input', $event.target.value)">
  </textarea>
</template>


<script>
import _ from "lodash";


export default {
    data: () => ({taID: _.uniqueId("tinymce-vue-")}),
    props:['value'],
    mounted: function () {
        let editor = window.initRichTextEditor(this.$refs.textarea);
        const self = this;
        editor.then((editors) => {
            let [editorInstance] = editors;
            editorInstance.on('change input undo redo', () => {
                self.$emit('input', editorInstance.getContent());
            });
        });
    },
    beforeUnmount: function () {
        window.tinymce.remove(this.$refs.textarea);
    },
}
</script>
