import tinymce from 'tinymce/tinymce';
import 'tinymce/themes/silver';
import 'tinymce/plugins/link';
import 'tinymce/plugins/lists';
import 'tinymce/plugins/image';
import 'tinymce/plugins/table';
import 'tinymce/plugins/code';
import 'tinymce/plugins/paste';
import Axios from '../config/axios';

function handleUpload(blobInfo, success, failure, progress) {
    const config = {
        onUploadProgress: function onUploadProgress(event) {
            progress(Math.round(event.loaded / event.total * 100));
        }
    };
    let formData = new FormData();
    formData.append('image', blobInfo.blob(), blobInfo.filename());
    formData.append('name', blobInfo.name());
    Axios.post('/image/', formData, config).then((response) => {
        success(response.data.location);
    }, (result) => failure(result, {remove: true}));
}

function firstInaccessibleImage(editor) {
  let images = editor.getDoc().getElementsByTagName("IMG");
  for(let ii= 0; ii < images.length; ii++) {
    let image = images[ii];
    if (!image.alt) {

      //editor.execCommand('mceImage');
      return image;
    }
  }
  return null;
}

function checkAllyShip(editor) {
  editor.ui.registry.addToggleButton('checkAlly', {
    text: 'Check Accessibility',
    classes: "a11y-check",
    onSetup: function(api) {
      function handleChange() {
        let inaccessible = !!firstInaccessibleImage(editor);
        console.log(`A11Y Check: ${inaccessible}`);
        if (inaccessible) {
          api.setActive(inaccessible);
          api.setDisabled(false);
        } else {
          api.setActive(false);
          api.setDisabled(true);
        }
      }
      const dirtyWatcher = editor.on('Dirty', handleChange);
      const changeWatcher = editor.on('change', handleChange);
      return function() {
        editor.off('Dirty', dirtyWatcher);
        editor.off('change', changeWatcher);
      };

    },
    onAction: function () {
      let image = firstInaccessibleImage(editor);
      if(image) {
        editor.execCommand('mceSelectNode', false, image);
      } else {
        console.error("Oops!");
      }
    }});
}

function imageAltContextForm(editor) {
  function isImage (node) {
    return node.nodeName.toLowerCase() === 'img';
  }

  editor.ui.registry.addContextForm('image-alt', {
    launch: {
      type: 'contextformtogglebutton',
      icon: 'accessibility-check'
    },
    label: 'description',
    predicate: isImage,
    position: 'node',
    initValue: function (arg) {
      return editor.selection.getNode().alt || defaultDescription;
    },
    commands: [
      {
        type: 'contextformtogglebutton',
        tooltip: 'Save',
        icon: 'save',
        primary: true,
        onAction: function (formApi) {
          var value = formApi.getValue();
          if (value !== defaultDescription) {
            editor.selection.getNode().alt = value;
            editor.setDirty(false);
            editor.setDirty(true);
          }
          formApi.hide();
        }
      },
      {
        type: 'contextformtogglebutton',
        icon: 'image',
        tooltip: 'More image options',
        active: true,
        onAction: function (formApi) {
          formApi.hide();
          editor.execCommand('mceImage');
        }
      }
    ]
  });
}

const defaultDescription = 'Image description';

const SUP = window.SUP;

function initRichTextEditor(element, code=false) {
    let plugins = ['link', 'lists', 'image', 'table', 'paste'];
  // toolbar options: https://www.tiny.cloud/docs/advanced/editor-control-identifiers/#toolbarcontrols
    let toolbar = 'undo redo removeformat | styleselect | h1 h2 | bold italic underline | numlist bullist indent outdent | table blockquote link image removeformat';
  if (SUP) {
    toolbar += ' | checkAlly';
  }
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
    content_style: SUP ? 'img[alt=""] {outline: 4px solid red;}' : '',
    menubar: false,
    branding: false,
    toolbar: toolbar,
    image_uploadtab: SUP,
    images_upload_handler: handleUpload,
    images_upload_credentials: true,
    automatic_uploads: true,
    contextmenu_never_use_native: false,
    contextmenu:false,
    paste_auto_cleanup_on_paste : true,
    paste_remove_styles: true,
    paste_remove_styles_if_webkit: true,
    paste_strip_class_attributes: "all",
    setup: (editor) => {
      if (SUP) {
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
