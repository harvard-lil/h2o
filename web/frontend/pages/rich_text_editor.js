import tinymce from 'tinymce/tinymce';
import 'tinymce/themes/silver';
import 'tinymce/plugins/link';
import 'tinymce/plugins/lists';
import 'tinymce/plugins/image';
import 'tinymce/plugins/table';
import 'tinymce/plugins/code';
import 'tinymce/plugins/paste';
import 'tinymce/plugins/media';
import 'tinymce/plugins/noneditable';
import {handleImageUpload, checkAllyShip, imageAltContextForm, installFootnotes} from '../libs/tinymce_extensions';

const ENHANCED = window.VERIFIED || window.SUP;

function initRichTextEditor(element, code=false) {
    let plugins = ['link', 'lists', 'image', 'table', 'paste'];
  // toolbar options: https://www.tiny.cloud/docs/advanced/editor-control-identifiers/#toolbarcontrols
    let toolbar = 'undo redo removeformat | styleselect | h1 h2 | bold italic underline | numlist bullist indent outdent | table blockquote link image removeformat';
  if (ENHANCED) {
    toolbar += ' | footnote media checkAlly';
    plugins.push('media');
  }
  if (code){
    plugins.push('code');
    toolbar += ' | code';
  }
  // Vue rebuilds the whole dom in between the call to init and tinymce actually doing the init
  // so we use a selector here until we use vue to init tinymce
  const selector=`${element.type}#${element.id}`;
  const semanticStyles = 'img[alt=""] {outline: 4px solid red;}.footnote-ref {font-size: 16px;vertical-align: super;}.footnote-body {margin-left: 2rem;}.footnote-label {float:left;margin-left:-1rem;} .footnote-label::after{content: ".";} .footnote-footer {border-top: 1px solid black;}';
  tinymce.init({
    selector: selector,
    plugins: plugins,
    skin_url: '/static/tinymce_skin',
    content_style: semanticStyles,
    menubar: false,
    branding: false,
    toolbar: toolbar,
    image_uploadtab: ENHANCED,
    images_upload_handler: handleImageUpload,
    images_upload_credentials: true,
    automatic_uploads: true,
    contextmenu_never_use_native: false,
    contextmenu:false,
    paste_auto_cleanup_on_paste : true,
    paste_remove_styles: true,
    paste_remove_styles_if_webkit: true,
    paste_strip_class_attributes: "all",
    extended_valid_elements: 'div[class|title|style|tabindex|id|class|data-custom-style],span[class|title|style|tabindex|id|class|data-custom-style]',
    setup: (editor) => {
      if (ENHANCED) {
        installFootnotes(editor);
        checkAllyShip(editor);
        imageAltContextForm(editor);
      }
    }
  });
}

for (const textArea of document.querySelectorAll('.richtext-editor'))
  initRichTextEditor(textArea);

for (const textArea of document.querySelectorAll('.richtext-editor-src'))
  initRichTextEditor(textArea, true);

global.initRichTextEditor = initRichTextEditor;
