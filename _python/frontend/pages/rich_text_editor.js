import tinymce from 'tinymce/tinymce';
import 'tinymce/themes/silver';
import 'tinymce/plugins/link';
import 'tinymce/plugins/lists';
import 'tinymce/plugins/image';
import 'tinymce/plugins/table';

function initRichTextEditor(element) {
  tinymce.init({
    target: element,
    plugins: ['link', 'lists', 'image', 'table'],
    skin_url: '/static/tinymce_skin',
    menubar: false,
    branding: false,
    // toolbar options: https://www.tiny.cloud/docs/advanced/editor-control-identifiers/#toolbarcontrols
    toolbar: 'undo redo removeformat | styleselect | bold italic underline | numlist bullist indent outdent | table blockquote link image'
  });
}

for (const textArea of document.querySelectorAll('.ckeditor'))
  initRichTextEditor(textArea);

global.initRichTextEditor = initRichTextEditor;
