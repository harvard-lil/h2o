<template>
<textarea ref="textarea" :id="taID" v-model="value">
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
    beforeDestroy: function () {
        window.tinyMCE.remove(this.$refs.textarea);
    },
}
</script>
