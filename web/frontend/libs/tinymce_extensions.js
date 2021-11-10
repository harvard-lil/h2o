import uuid from 'uuid';
import Axios from '../config/axios';
import _ from 'lodash';

const defaultDescription = 'Image description';

export function handleImageUpload(blobInfo, success, failure, progress) {
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
      return image;
    }
  }
  return null;
}

export function checkAllyShip(editor) {
  let tinymceEditor = editor;
  editor.ui.registry.addToggleButton('checkAlly', {
    text: 'Check Accessibility',
    classes: "a11y-check",
    onSetup: function(api) {
      function handleChange() {
        let inaccessible = !!firstInaccessibleImage(editor);
        if (inaccessible) {
          api.setActive(inaccessible);
          api.setDisabled(false);
        } else {
          api.setActive(false);
          api.setDisabled(true);
        }
      }
      const dirtyWatcher = tinymceEditor.on('Dirty', handleChange);
      const changeWatcher = tinymceEditor.on('change', handleChange);
      return function() {
        tinymceEditor.off('Dirty', dirtyWatcher);
        tinymceEditor.off('change', changeWatcher);
      };

    },
    onAction: function () {
      let image = firstInaccessibleImage(editor);
      if(image) {
        tinymceEditor.execCommand('mceSelectNode', false, image);
      }
    }});
}

export function imageAltContextForm(editor) {
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


export function installFootnotes(editor) {
  function _isFootnoteRef(node) {
    return node.classList.contains('footnote-ref');
  }

  function _isFootnoteBody(node) {
    return node.classList.contains('footnote-label') || node.classList.contains('footnote-body');
  }

  function isFootnote(node) {
    return node.classList.contains('footnote');
  }


  function getFootnoteNodePair(id) {
    let refNode = editor.dom.get(`footnote-${id}-ref`);
    let bodyNode = editor.dom.get(`footnote-${id}`);
    return { refNode, bodyNode };
  }

  function footnoteIntegrity() {
    // On nodechanges, search for every footnote, and make sure it's paired up properly to check for deletions.
    let candidates = editor.dom.$('.footnote').filter((_,e) => !e.classList.contains('footnote-footer'));
    // Association lists to maintain order
    let refs = [];
    let bodies = [];
    for(let ii = 0; ii < candidates.length; ii++) {
      let candidate = candidates[ii];
      let id = getFootnoteId(candidate);
      if(candidate.classList.contains('footnote-ref')) {
        let mark = candidate.innerText;
        refs.push({id,candidate,mark});
      } else if (candidate.classList.contains('footnote-body')) {
        let label = candidate.getElementsByClassName('footnote-label');
        let mark;
        if (!label || label.length == 0) {
          if (candidate.innerText.trim() !== "") {
            mark = '';
            bodies.push({id,candidate,mark});
          }
        } else {
          mark = label[0].innerText;
          bodies.push({id,candidate,mark});
        }

      }
    }

    let refsById = _.chain(refs).groupBy('id').mapValues(x => x[0]).value();
    let bodiesById = _.chain(bodies).groupBy('id').mapValues(x => x[0]).value();
    let orphanedRefs = _.differenceBy(refs, bodies, 'id');
    let orphanedBodies = _.differenceBy(bodies, refs, 'id');

    // Delete the other half of orphaned Refs.
    orphanedRefs.forEach(function({id, candidate}) {
      editor.dom.remove(candidate);
      _.unset(refsById, id);
    });
    orphanedBodies.forEach(function({id, candidate}) {
      editor.dom.remove(candidate);
      _.unset(bodiesById, id);
    });

    // Adjust marks if necessary
    _.values(refsById).forEach(function({id, mark, candidate}) {
      let bodyMark = bodiesById[id].mark;
      if (mark !== bodyMark) {
        let bodyDom = bodiesById[id].candidate;
        let labelDom = bodyDom.getElementsByClassName('footnote-label');
        if(! labelDom || labelDom.length == 0) {
          if (bodyDom.firstChild) {
            labelDom = editor.dom.createFragment(`<span class="footnote-label" data-extra-export-offset="2">${mark}</span>`);
            bodyDom.firstChild.prepend(labelDom);
          }
        } else {
          labelDom[0].innerText = mark;
        }
        // let dataMark = bodyDom.attributes['data-mark'];
        // dataMark.value = mark;
        // bodyDom.attributes.setNamedItem(dataMark);
      }
    });

    // Clean up orphaned labels
    let labelsDom = editor.dom.$('.footnote-label');
    let labels = [];
    for(let ii=0; ii < labelsDom.length; ii++) {
      labels.push(labelsDom[ii]);
    }
    labels.forEach(label => {
      let parent = label;
      while (parent) {
        if (parent.classList.contains('footnote-footer')) {
          return;
        }
        parent = parent.parentElement;
      }
      editor.dom.remove(label);
    });

    // Ensure footnotes have at least one space
    // So that the cursor doesn't jump to the start of a label
    labelsDom = editor.dom.$('.footnote-label');
    labels = [];
    for(let ii=0; ii < labelsDom.length; ii++) {
      labels.push(labelsDom[ii]);
    }
    labels.forEach(label => {
      let parentText = label.parentElement.innerText;
      if (parentText.trim() == label.innerText) {
        let space = document.createTextNode(" ");
        label.parentElement.appendChild(space);
        editor.selection.setCursorLocation(label.parentElement, parentText.length);
      }
    });

    // Make sure selection isn't inside of label
    if (editor.selection.getStart() == editor.selection.getEnd() && editor.selection.getStart().classList.contains('footnote-label')) {
      let label = editor.selection.getStart();
      editor.selection.setCursorLocation(label.parentElement, label.innerText.length);
    }

    // Move footer to bottom of page
    let footer = editor.dom.$('.footnote-footer');
    if(footer.length === 1) {
      footer = footer[0];
      if (footer !== footer.parentElement.lastElementChild) {
        footer.parentElement.appendChild(footer);
      }
    }
  }

  function getFooter() {
    let footnoteDiv = editor.dom.$(".footnote-footer");
    if (footnoteDiv.length == 1) {
      return footnoteDiv[0];
    }
    if(footnoteDiv.length > 1) {
      console.error("Multiple footers present.");
      return null;
    }

    let footer = editor.dom.add(editor.getBody(), 'div', {class: 'footnote footnote-footer'}, '');
    return footer;
  }

  function createFootnote(data) {
    data.id = uuid();
    let refHTML = `<span class="footnote footnote-ref" data-custom-style="Footnote Reference" id="footnote-${data.id}-ref">${data.mark}</span>`;
    let bodyNode = editor.dom.createFragment(`<div class="footnote footnote-body" id="footnote-${data.id}"><p><span class="footnote-label" data-extra-export-offset="2" contenteditable="false">${data.mark}</span>${data.footnote}</p></div>`);

    let footer = getFooter();
    footer.appendChild(bodyNode);
    editor.execCommand("mceInsertContent", false, refHTML);
  }

  function updateFootnote(data) {
    let {refNode, bodyNode} = getFootnoteNodePair(data.id);
    refNode.innerText = data.mark;
    let bodyContent = editor.dom.createFragment(`<p><span class="footnote-label" data-extra-export-offset="2" contenteditable="false">${data.mark}</span>${data.footnote}</p>`);
    while(bodyNode.firstChild) {bodyNode.firstChild.remove();}
    bodyNode.appendChild(bodyContent);
  }

  function getFootnoteData(id) {
    let {refNode, bodyNode} = getFootnoteNodePair(id);
    let mark = refNode.innerText;
    let redundantMark = bodyNode.firstChild.firstChild.innerText;
    let footnote = bodyNode.innerText.substr(redundantMark.length).trim();
    return {mark, footnote, id};
  }

  function getFootnoteId(node) {
    let htmlID = node.id || node.parentElement.id;
    if(htmlID) {
      return htmlID.substr(9,36);
    }
    return null;
  }

  function openDialog() {
    let currentNode = editor.selection.getNode();
    let isEditingNode = isFootnote(currentNode);
    let nextFootnote = editor.dom.$(".footnote-ref").length + 1;
    let currentData = {mark: ""+nextFootnote, footnote: ""};

    if(isEditingNode) {
      let id = getFootnoteId(currentNode);
      currentData = getFootnoteData(id);
    }
    editor.windowManager.open({
      title: 'Footnote',
      size: 'normal',
      body: {
        type: 'panel',
        items : [
          {
            label: 'Mark',
            type: 'input',
            name: 'mark'
          },
          {
            label: 'Footnote',
            type:'textarea',
            name: 'footnote',
            multiline: true,
            minWidth: 520,
            minHeight: 100,
          }
        ],
      },
      buttons: [
        {
          type: 'cancel',
          name: 'cancel',
          text: 'Cancel'
        },
        {
          type: 'submit',
          name: 'save',
          text: 'Save',
          primary: true
        },
        {
          type: 'custom',
          name: 'delete',
          text: 'Delete'
        }
      ],
      initialData: currentData,
      onSubmit: function (dialog) {
        let data = dialog.getData();
        if (isEditingNode) {
          data.id = currentData.id;
          updateFootnote(data);
        } else {
          createFootnote(data);
        }
        dialog.close();
      },
      onCancel: function(dialog) {
        dialog.close();
      },
      onAction: function(dialog, details) {
        if (details && details.name == "delete") {
          let {refNode, bodyNode} = getFootnoteNodePair(currentData.id);
          refNode.remove();
          bodyNode.remove();
        }
        dialog.close();
      }
    });
  }

  var Dialog = { open: openDialog };

  editor.ui.registry.addToggleButton('footnote', {
    text: 'Footnote',
    tooltip : 'Footnote',
    onAction: function () {
      return editor.execCommand('openFootnote');
    }
  });
  editor.ui.registry.addMenuItem('footnote', {
    text: 'Footnote',
    onAction: function () {
      return editor.execCommand('openFootnote');
    }
  });
  editor.addCommand('openFootnote', function () {
    Dialog.open(editor);
  });

  editor.on("NodeChange", function(e) {
    footnoteIntegrity();
  });
}



export function getInitConfig(selector, enhanced, code) {

  const semanticStyles = 'img[alt=""] {outline: 4px solid red;}.footnote-ref {font-size: 16px;vertical-align: super;}.footnote-body {margin-left: 2rem;}.footnote-label {float:left;margin-left:-1rem;} .footnote-label::after{content: ".";} .footnote-footer {border-top: 1px solid black;clear:both;}.image-center-large{width:80%;object-fit:contain;margin:0auto;display:block;}.image-center-medium{width:50%;object-fit:contain;margin:0 auto;display:block;}.image-left-medium{width:50%;object-fit:contain;margin:0 2rem;float:left;display:block;}.image-right-medium{width:50%;object-fit:contain;margin:0 2rem;float:right;display:block;}';

  let plugins = ['link', 'lists', 'image', 'table', 'paste'];
  // toolbar options: https://www.tiny.cloud/docs/advanced/editor-control-identifiers/#toolbarcontrols

  let toolbar = 'undo redo removeformat | styleselect | h1 h2 | bold italic underline | numlist bullist indent outdent | table blockquote link image removeformat';
  if (enhanced) {
    toolbar += ' media footnote | checkAlly';
    plugins.push('media');
  }
  if (code){
    plugins.push('code');
    toolbar += ' | code';
  }

  let extend_valid_elements = [['div', ['class', 'title', 'style', 'tabindex', 'id', 'class', 'data-custom-style']],
                               ['span', ['class', 'title', 'style', 'tabindex', 'id', 'class', 'data-custom-style'],
                                ['img', ['class', 'alt', 'title', 'id', 'data-custom-style']]]]
      .map(x => `${x[0]}[${x[1].join('|')}]`)
      .join(',');

  let image_class_list = [{title: 'Large centered', value: 'image-center-large'},
                          {title: 'Center aligned', value: 'image-center-medium'},
                          {title: 'Left aligned', value: 'image-left-medium'},
                          {title: 'Right aligned', value: 'image-right-medium'}
                         ];
  let config = {
    height:'60vh',
    plugins: plugins,
    skin_url: '/static/tinymce_skin',
    content_style: semanticStyles,
    menubar: false,
    branding: false,
    toolbar: toolbar,
    image_uploadtab: enhanced,
    images_upload_handler: handleImageUpload,
    images_upload_credentials: true,
    image_dimensions: false,
    image_class_list: image_class_list,
    automatic_uploads: true,
    contextmenu_never_use_native: false,
    contextmenu:false,
    paste_auto_cleanup_on_paste : true,
    paste_remove_styles: true,
    paste_remove_styles_if_webkit: true,
    paste_strip_class_attributes: "all",
    media_dimensions: false,
    extended_valid_elements: extend_valid_elements,
    setup: (editor) => {
      if (enhanced) {
        installFootnotes(editor);
        checkAllyShip(editor);
        imageAltContextForm(editor);
      }
    }
  };

  if (selector) {
    config.selector = selector;
  }
  return config;
}
