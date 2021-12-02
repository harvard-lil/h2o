import tinymce from 'tinymce/tinymce';
window.tinymce = tinymce;
import 'tinymce/themes/silver';
import 'tinymce/icons/default';
import 'tinymce/plugins/link';
import 'tinymce/plugins/lists';
import 'tinymce/plugins/image';
import 'tinymce/plugins/table';
import 'tinymce/plugins/code';
import 'tinymce/plugins/paste';
import 'tinymce/plugins/media';
import 'tinymce/plugins/noneditable';
import {getInitConfig} from '../libs/tinymce_extensions';

const ENHANCED = window.VERIFIED || window.SUP;

function initRichTextEditor(element, code=false) {
  // Vue rebuilds the whole dom in between the call to init and tinymce actually doing the init
  // so we use a selector here until we use vue to init tinymce
  const selector=`${element.type}#${element.id}`;
  let config = getInitConfig(selector, ENHANCED, code);

  return tinymce.init(config);
}

for (const textArea of document.querySelectorAll('.richtext-editor'))
  initRichTextEditor(textArea);

for (const textArea of document.querySelectorAll('.richtext-editor-src'))
  initRichTextEditor(textArea, true);

global.initRichTextEditor = initRichTextEditor;
