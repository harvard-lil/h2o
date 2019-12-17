import tinymce from 'tinymce/tinymce';
import 'tinymce/themes/silver';
import 'tinymce/plugins/link';
import 'tinymce/plugins/lists';
import 'tinymce/plugins/image';
import 'tinymce/plugins/table';
import 'tinymce/plugins/code';

function initRichTextEditor(element, code=false) {
  let plugins = ['link', 'lists', 'image', 'table'];
  // toolbar options: https://www.tiny.cloud/docs/advanced/editor-control-identifiers/#toolbarcontrols
  let toolbar = 'undo redo removeformat | styleselect | bold italic underline | numlist bullist indent outdent | table blockquote link image';
  if (code){
    plugins.push('code');
    toolbar += ' | code';
  }
  tinymce.init({
    target: element,
    plugins: plugins,
    skin_url: '/static/tinymce_skin',
    menubar: false,
    branding: false,
    toolbar: toolbar
  })
}

for (const textArea of document.querySelectorAll('.richtext-editor'))
  initRichTextEditor(textArea);

for (const textArea of document.querySelectorAll('.richtext-editor-src'))
  initRichTextEditor(textArea, true);

global.initRichTextEditor = initRichTextEditor;
