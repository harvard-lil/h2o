import ClassicEditor from '@ckeditor/ckeditor5-build-classic';

function initCkEditor(element) {
  ClassicEditor
    .create(element, {
      // see https://ckeditor.com/docs/ckeditor5/latest/builds/guides/integration/configuration.html
      toolbar: ['heading', '|', 'bold', 'italic', 'link', 'bulletedList', 'numberedList', '|', "indent", "outdent", '|', 'blockQuote', 'insertTable', "mediaEmbed", "undo", "redo"],
      // "imageUpload" is currently excluded from the above list, but could be added with server-side support.
      // to add image hotlinking: https://ckeditor.com/docs/ckeditor5/latest/framework/guides/creating-simple-plugin.html#step-4-inserting-a-new-image
    })
    .then(editor => {
      // to print all toolbar options:
      // console.log("TOOLBAR", Array.from(editor.ui.componentFactory.names()));
      // results: ["undo", "redo", "bold", "italic", "blockQuote", "ckfinder", "imageTextAlternative", "imageUpload",
      // "heading", "imageStyle:full", "imageStyle:side", "indent", "outdent", "link", "numberedList", "bulletedList",
      // "mediaEmbed", "insertTable", "tableColumn", "tableRow", "mergeTableCells"],
    } )
    .catch(error => {
      console.log("Error loading CKEditor", error);
    });
}

for (const textArea of document.querySelectorAll('.ckeditor'))
  initCkEditor(textArea);

global.initCkEditor = initCkEditor;
