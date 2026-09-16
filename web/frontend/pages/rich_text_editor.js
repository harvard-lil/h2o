import tinymce from 'tinymce/tinymce';
window.tinymce = tinymce;
import 'tinymce/themes/silver';
import 'tinymce/models/dom';
import 'tinymce/skins/ui/oxide/skin.css';
import contentStyle from 'tinymce/skins/content/default/content.css?inline';
import uiContentStyle from 'tinymce/skins/ui/oxide/content.css?inline';
import 'tinymce/icons/default';
import 'tinymce/plugins/link';
import 'tinymce/plugins/lists';
import 'tinymce/plugins/image';
import 'tinymce/plugins/table';
import 'tinymce/plugins/code';
import 'tinymce/plugins/media';
import {getInitConfig} from '../libs/tinymce_extensions';

const ENHANCED = window.ENABLE_MEDIA_UPLOAD;

function initRichTextEditor(element, code=false) {
  const selector=`${element.type}#${element.id}`;
  const config = getInitConfig(selector, ENHANCED, code);
  Object.assign(config, { skin: false, content_css: false, content_style: uiContentStyle + contentStyle + config.content_style, license_key: "gpl" });

  return tinymce.init(config);
}

// Vue mounts the server-rendered page before editors attach to its textareas.
document.addEventListener('DOMContentLoaded', () => {
  for (const textArea of document.querySelectorAll('.richtext-editor'))
    initRichTextEditor(textArea);

  for (const textArea of document.querySelectorAll('.richtext-editor-src'))
    initRichTextEditor(textArea, true);

});

window.initRichTextEditor = initRichTextEditor;
