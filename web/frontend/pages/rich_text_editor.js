import tinymce from 'tinymce/tinymce';
import 'tinymce/themes/silver';
import 'tinymce/plugins/link';
import 'tinymce/plugins/lists';
import 'tinymce/plugins/image';
import 'tinymce/plugins/table';
import 'tinymce/plugins/code';
import 'tinymce/plugins/paste';

function initRichTextEditor(element, code=false) {
    let plugins = ['link', 'lists', 'image', 'table', 'paste'];
  // toolbar options: https://www.tiny.cloud/docs/advanced/editor-control-identifiers/#toolbarcontrols
  let toolbar = 'undo redo removeformat | styleselect | h1 h2 | bold italic underline | numlist bullist indent outdent | table blockquote link image removeformat';
  if (code){
    plugins.push('code');
    toolbar += ' | code';
  }
  // Vue rebuilds the whole dom in between the call to init and tinymce actually doing the init
  // so we use a selector here until we use vue to init tinymce
  const selector=`${element.type}#${element.id}`;
  tinymce.init({
    selector: selector,
    plugins: plugins,
    skin_url: '/static/tinymce_skin',
    menubar: false,
    branding: false,
    toolbar: toolbar,
    contextmenu_never_use_native: false,
      contextmenu:false,
      paste_auto_cleanup_on_paste : true,
      paste_remove_styles: true,
      paste_remove_styles_if_webkit: true,
      paste_strip_class_attributes: "all"
  });
}

for (const textArea of document.querySelectorAll('.richtext-editor'))
  initRichTextEditor(textArea);

for (const textArea of document.querySelectorAll('.richtext-editor-src'))
  initRichTextEditor(textArea, true);

global.initRichTextEditor = initRichTextEditor;
