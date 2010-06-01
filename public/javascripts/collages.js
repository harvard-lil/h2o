jQuery.extend({
formatRange: function(){
  var sel = window.getSelection();
  var anchor_x_path = '';
  var anchorNode = sel.anchorNode;
  var anchor_offset = 0;
  var anchor_sibling_offset = 0;

  var focus_x_path = '';
  var focusNode = sel.focusNode;
  var focus_offset = 0;
  var focus_sibling_offset = 0;

  if(window.console){
    console.log('Anchor Node');
    console.log(anchorNode);
    console.log('Focus Node');
    console.log(focusNode);
  }

  var detected_select_type = '';
  var range = null;
  if((anchorNode === focusNode)){
    //Everything happens in a single node.
    if(anchorNode.nodeName == '#text'){
      //This is a selection in the same node and it isn't the entire node.
      detected_select_type = 'single node';
      if (window.console){
        console.log('You have selected part of a singular node');
      }
      anchor_offset = sel.anchorOffset;
      focusNode = anchorNode;
      focus_offset = sel.focusOffset;

      if(focus_offset < anchor_offset){
        // They selected from right-to-left.
        if(window.console){
          console.log('selected from right-to-left');
        }
        focus_offset = sel.anchorOffset;
        anchor_offset = sel.focusOffset;

      }
      anchor_x_path = '/' + jQuery.getXPath(anchorNode).join('/'); 
      focus_x_path = anchor_x_path;

      if (window.console){
        console.log('Anchor Node:' + anchorNode + ' anchor_offset:' + anchor_offset + ' focusNode: ' + focusNode + ' focus_offset: ' + focus_offset);
      }
      for(var i=0; i <= anchorNode.parentNode.childNodes.length; i++){
        if(anchorNode.parentNode.childNodes[i] == anchorNode){
          anchor_sibling_offset = i;
        }
      }
      focus_sibling_offset = anchor_sibling_offset;

    } else if(sel.focusOffset == anchorNode.childNodes.length){
      //They have selected an entire node, singularly.
      detected_select_type = 'entire single node';
      if (window.console){
        console.log('You have selected an entire node- just one.');
      }
      anchor_offset = 0;
      focus_offset = sel.focusOffset;
      if (window.console){
        console.log('Anchor Node:' + anchorNode + ' anchor_offset:' + anchor_offset + ' focusNode: ' + focusNode + ' focus_offset: ' + focus_offset);
      }
      anchor_x_path = '/' + jQuery.getXPath(anchorNode).join('/');
      focus_x_path = anchor_x_path;
      anchor_sibling_offset = null;
      focus_sibling_offset = null;
    } else {
      // It's in a single node but spans multiple siblings.

      detected_select_type = 'single node, multiple siblings';
      anchor_sibling_offset = sel.anchorOffset;
      focus_sibling_offset = sel.focusOffset;

      if (window.console){
        console.log('Single node spanning multiple siblings');
        console.log('Anchor Node:' + anchorNode + ' anchor_offset:' + anchor_offset + ' focusNode: ' + focusNode + ' focus_offset: ' + focus_offset);
      }

      anchor_x_path = '/' + jQuery.getXPath(anchorNode).join('/');
      focus_x_path = anchor_x_path;
      anchor_offset = 0;
      focus_offset = 0;
    }
  } else {
    // This is a selection that spans nodes
    if (window.console){
      console.log('This selection spans nodes');
    }

  if(jQuery.browser.mozilla){
    if(focusNode.nodeName !== '#text'){
      if((sel.focusOffset - sel.anchorOffset)>1){
         //spanning more than one.
        focusNode = anchorNode
      } else if ( anchorNode.childNodes[sel.anchorOffset].nodeName !== '#text' ) {
        //Non-text.
        focusNode = sel.anchorNode.childNodes[sel.anchorOffset];
      }	else {
        //Whole element.
        focusNode = sel.anchorNode;
      }
    }
  }
    detected_select_type = 'multiple node span';
    anchor_offset = sel.anchorOffset;
    anchor_sibling_offset = 0;
    focus_offset = sel.focusOffset;
    focus_sibling_offset = 0;

    for(var i=0; i <= anchorNode.parentNode.childNodes.length; i++){
      if(anchorNode.parentNode.childNodes[i] == anchorNode){
        anchor_sibling_offset = i;
      }
    }
    for(var i=0; i <= focusNode.parentNode.childNodes.length; i++){
      if(focusNode.parentNode.childNodes[i] == focusNode){
        focus_sibling_offset = i;
      }
    }
    anchor_x_path = '/' + jQuery.getXPath(anchorNode).join('/'); 
    focus_x_path = '/' + jQuery.getXPath(focusNode).join('/');
  }

  var anchorString = [anchor_x_path, anchor_sibling_offset, anchor_offset].join('-');
  var focusString = [focus_x_path, focus_sibling_offset, focus_offset].join('-');

  if(jQuery("#selector_info").length > 0){
    jQuery('#select_type').html(detected_select_type);
    jQuery('#anchor_x_path').html(anchor_x_path);
    jQuery('#anchor_sibling_offset').html(anchor_sibling_offset);
    jQuery('#anchor_offset').html(anchor_offset);
    jQuery('#focus_x_path').html(focus_x_path);
    jQuery('#focus_sibling_offset').html(focus_sibling_offset);
    jQuery('#focus_offset').html(focus_offset);
  }

  if((anchor_x_path.match(/annotatable\-content/) && focus_x_path.match(/annotatable\-content/)) && (anchorString != focusString)){
    return {anchor_x_path: anchor_x_path, anchor_sibling_offset: anchor_sibling_offset, anchor_offset: anchor_offset, focus_x_path: focus_x_path, focus_sibling_offset: focus_sibling_offset, focus_offset: focus_offset}
  } else {
    throw 'It looks like you didn\'t select something, or you selected something that can\'t be annotated or excerpted.';
  }
},

storeRange: function(range,rangeObj){
  var collageId = jQuery('.collage-id').attr('id').split('-')[1];
  rangeObj['collage_id'] = collageId;
  jQuery.ajax({
    type: 'POST',
    url: jQuery.rootPath() + 'excerpts/create',
    data: rangeObj,
    beforeSend: function(){
      jQuery('#spinner_block').show();
      jQuery('div.ajax-error').html('').hide();
    },
    success: function(response){
      jQuery('#spinner_block').hide();
      jQuery.collapseRange(range,response.excerpt.excerpt);
    },
    error: function(xhr){
      jQuery('#spinner_block').hide();
      jQuery('div.ajax-error').show().append(xhr.responseText);
    }
  });
},

createRange: function(rangeObj){
  var anchorXPathNode = jQuery.evalXPath(rangeObj.anchor_x_path);
  var focusXPathNode = jQuery.evalXPath(rangeObj.focus_x_path);
  if(window.console){
    console.log('In createRange:');
    console.log(rangeObj);
  }
  try{
    var range = document.createRange();
    range.setStart((rangeObj.anchor_sibling_offset != null) ? anchorXPathNode.childNodes[rangeObj.anchor_sibling_offset] : anchorXPathNode,rangeObj.anchor_offset);
    range.setEnd((rangeObj.focus_sibling_offset != null) ? focusXPathNode.childNodes[rangeObj.focus_sibling_offset] : focusXPathNode,rangeObj.focus_offset);
  } catch (err){
    jQuery('div.ajax-error').show().html(err + 'Failed to create range.');
  }
  return range;
},

collapseRange: function(range,obj){
  range.deleteContents();
  var node = document.createElement('span');
  node.setAttribute('id', 'excerpt-control-' + obj.id);
  node.appendChild(document.createTextNode('. . .'));
  node.className = 'excerpt-control';
  node.setAttribute('title', 'Click to expand');
  range.insertNode(node);
  jQuery('#excerpt-control-' + obj.id).button({icons: {primary: 'ui-icon-scissors'}}).click(function(e){
    e.preventDefault();
    var excerptId = jQuery(this).attr('id').split('-')[2];
    alert('FIXME - Implement excerpt management controls.');
  });
},

annotateRange: function(range,obj){
  var node = jQuery('<span class="annotation-control"></span>');
  node.attr('id', 'annotation-control-' + obj.id);
  node.attr('title', 'Click to see annotation');
  node.html('&nbsp;');
  if(window.console){
    console.log('trying to insert annotation');
    console.log(node);
  }
  var activeLayer = jQuery.cookie('active-layer');

  var hasActiveLayer = false;
  jQuery(obj.layers).each(function(){
      if(this.id == activeLayer){
        hasActiveLayer = true;
      }
  });

  if(hasActiveLayer){
    range.deleteContents();
  }

  range.insertNode(node[0]);
  jQuery(node).button({icons: {primary: 'ui-icon-script'}}).click(function(e){
    e.preventDefault();
    var annotationId = jQuery(this).attr('id').split('-')[2];
    if(jQuery('#annotation-details-' + annotationId).length == 0){
      jQuery.ajax({
        type: 'GET',
        url: jQuery.rootPath() + 'annotations/' + annotationId,
        beforeSend: function(){
          jQuery('#spinner_block').show();
          jQuery('div.ajax-error').html('').hide();
        },
        error: function(xhr){
          jQuery('#spinner_block').hide();
          jQuery('div.ajax-error').show().append(xhr.responseText);
        },
        success: function(html){
          jQuery('#spinner_block').hide();
          var node = jQuery(html);
          jQuery('body').append(node);
          var dialog = jQuery('#annotation-details-' + annotationId).dialog({
            height: 300,
            title: 'Annotation Details',
            width: 400,
            position: [e.clientX,e.clientY - 330],
              buttons: {
                Close: function(){
                  jQuery(this).dialog('close');
                }
              }
          });
        }
      });
    } else {
      jQuery('#annotation-details-' + annotationId).dialog().open();
    }
  });
},

evalXPath: function(xpath){
  if (document.evaluate){
    return document.evaluate(xpath, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
  } else {//can not use xmldocument.selectSingleNode(xpath);
    var tags=xpath.slice(1).split('/');
    var ele=document;
    for (var i=0; i<tags.length; ++i){
      var idx=1;
      if (tags[i].indexOf('[')!=-1){
        idx=tags[i].split('[')[1].split(']')[0];
        tags[i]=tags[i].split('[')[0];
      }
      var ele=jQuery(ele).children(tags[i])[idx-1];
    }
    return ele;
  }
},

getXPath: function(node, path) {
  path = path || [];
  if(node.parentNode) {
    path = jQuery.getXPath(node.parentNode, path);
  }
  if(node.previousSibling) {
    var count = 1;
    var sibling = node.previousSibling
      do {
        if(sibling.nodeType == 1 && sibling.nodeName == node.nodeName) {count++;}
        sibling = sibling.previousSibling;
      } while(sibling);
    if(count == 1) {count = null;}
  } else if(node.nextSibling) {
    var sibling = node.nextSibling;
    do {
      if(sibling.nodeType == 1 && sibling.nodeName == node.nodeName) {
        var count = 1;
        sibling = null;
      } else {
        var count = null;
        sibling = sibling.previousSibling;
      }
    } while(sibling);
  }

  if(node.nodeType == 1) {
    path.push(node.nodeName.toLowerCase() + (node.id ? "[@id='"+node.id+"']" : count > 0 ? "["+count+"]" : ''));
  }
  return path;
},
observeExcerptControls: function(){
  jQuery('#excerpt-selection').click(function(e){
    e.preventDefault();
    try{
      var rangeObj = jQuery.formatRange();
      if (window.console){
        console.log(rangeObj);
      }
      var range = jQuery.createRange(rangeObj);
      jQuery.storeRange(range,rangeObj);
    } catch(err) {
      jQuery('#ajax-error').show().html(err + 'Failed to create excerpt controls');
    }
  });
},

observeAnnotationControls: function(){
  jQuery('#annotate-selection').click(function(e){
    var rangeObj = jQuery.formatRange();
    var collageId = jQuery('.collage-id').attr('id').split('-')[1];
    rangeObj['collage_id'] = collageId;
    var submitAnnotation = function(){
      jQuery('#new-annotation-form form').ajaxSubmit({
        error: function(xhr){
          jQuery('#spinner_block').hide();
          jQuery('#new-annotation-error').show().append(xhr.responseText);
        },
        beforeSend: function(){
          jQuery('#spinner_block').show();
          jQuery('div.ajax-error').html('').hide();
          jQuery('#new-annotation-error').html('').hide();
        },
        success: function(response){
          jQuery('#spinner_block').hide();
          jQuery('#new-annotation-form').dialog('close');
          var range = jQuery.createRange(response.annotation.annotation);
          jQuery.annotateRange(range,response.annotation.annotation);
        }
      });
    };
    jQuery('#new-annotation-form').dialog({
      bgiframe: true,
      autoOpen: false,
      minWidth: 300,
      width: 450,
      modal: true,
      title: 'New Annotation',
      buttons: {
        'Save': submitAnnotation,
        'Cancel': function(){
          jQuery('#new-annotation-error').html('').hide();
          jQuery(this).dialog('close');
        }
      }
    });
    e.preventDefault();
    jQuery.ajax({
      type: 'GET',
      url: jQuery.rootPath() + 'annotations/new',
      data: rangeObj,
      cache: false,
      beforeSend: function(){
        jQuery('#spinner_block').show();
        jQuery('div.ajax-error').html('').hide();
     },
      success: function(html){
        jQuery('#spinner_block').hide();
        jQuery('#new-annotation-form').html(html);
        jQuery('#new-annotation-form').dialog('open');
      },
      error: function(xhr){
        jQuery('#spinner_block').hide();
        jQuery('div.ajax-error').show().append(xhr.responseText);
      }
    });
    try{
      if (window.console){
        console.log(rangeObj);
      }
      var range = jQuery.createRange(rangeObj);
      if (window.console){
        console.log(range);
      }
    } catch(err) {
      jQuery('#ajax-error').show().html(err + 'Failed to observe annotation controls');
    }
  });
},

initializeExcerpts: function(){
  var collageId = jQuery('.collage-id').attr('id').split('-')[1];
  jQuery.ajax({
    type: 'GET',
    url: jQuery.rootPath() + 'collages/excerpts/' + collageId,
    cache: false,
    beforeSend: function(){
      jQuery('#spinner_block').show();
      jQuery('div.ajax-error').html('').hide();
    },
    success: function(json){
      jQuery('#spinner_block').hide();
      jQuery(json).each(function(){
        var range = jQuery.createRange(this.excerpt);
        jQuery.collapseRange(range,this.excerpt);
      });
    },
    error: function(xhr){
      jQuery('#spinner_block').hide();
      jQuery('div.ajax-error').show().append(xhr.responseText);
    }
  });
},

initializeAnnotations: function(){
  var collageId = jQuery('.collage-id').attr('id').split('-')[1];
  jQuery.ajax({
    type: 'GET',
    url: jQuery.rootPath() + 'collages/annotations/' + collageId,
    data: {layer_id: jQuery.cookie('active-layer')},
    cache: false,
    beforeSend: function(){
      jQuery('#spinner_block').show();
      jQuery('div.ajax-error').html('').hide();
    },
    success: function(json){
      if(window.console){
        console.log(json);
      }
      jQuery('#spinner_block').hide();
      jQuery(json).each(function(){
        var range = jQuery.createRange(this.annotation);
        jQuery.annotateRange(range,this.annotation);
      });
    },
    error: function(xhr){
      jQuery('#spinner_block').hide();
      jQuery('div.ajax-error').show().append(xhr.responseText);
    }

  });
},

initLayers: function(){
  var collageId = jQuery('.collage-id').attr('id').split('-')[1];
  jQuery.ajax({
    type:'GET',
    url: jQuery.rootPath() + 'collages/layers/' + collageId,
    cache: false,
    beforeSend: function(){
      jQuery('#spinner_block').show();
      jQuery('div.ajax-error').html('').hide();
      jQuery('#layer-list').html('');
    },
    success: function(json){
      jQuery('#spinner_block').hide();
      var output = '';
      var tagList = jQuery('#layer-list');
      var activeLayerId = jQuery.cookie('active-layer');
      jQuery(json).each(function(){
        var node = jQuery('<span class="layer-control"></span>');
        node.attr('id', 'layer-' + this.tag.id);
        if(this.tag.id == activeLayerId){
          node.addClass('layer-active');
        }
        var anchor = jQuery('<a>');
        anchor.attr('href', jQuery.rootPath() + 'collages/' + collageId);
        anchor.html(this.tag.name);

        node.html(anchor);
        tagList.append(node);
      });
      jQuery('.layer-control').click(function(){
          var layerId = jQuery(this).attr('id').split(/\-/)[1];
          jQuery('.layer-control').removeClass('layer-active');
          jQuery.cookie('active-layer',layerId);
          jQuery(this).addClass('layer-active');
      });
    },
    error: function(xhr){
      jQuery('#spinner_block').hide();
      jQuery('div.ajax-error').show().append(xhr.responseText);
    }
  });
},

observeUndo: function(){
  var collageId = jQuery('.collage-id').attr('id').split('-')[1];
  jQuery("a[id*='undo-']").click(function(e){
    e.preventDefault();
    var undoType = jQuery(this).attr('id').split('-')[1];
    if(!confirm("Undo the last " + undoType + '?')){
      return;
    }
    var url = jQuery.rootPath() + 'collages/' + collageId + '/undo_' + undoType;
    jQuery.ajax({
      type: 'POST',
      url: url,
      cache: false,
      beforeSend: function(){
        jQuery('#spinner_block').show();
        jQuery('div.ajax-error').html('').hide();
      },
      success: function(){
        window.location.href = jQuery.rootPath() + 'collages/' + collageId;
      },
      error: function(xhr){
        jQuery('#spinner_block').hide();
        jQuery('div.ajax-error').show().append(xhr.responseText);
      }
    });
  });
}

});

jQuery(document).ready(function(){
//    jQuery.observeExcerptControls();
//    jQuery.initializeExcerpts();
    jQuery.initLayers();
    jQuery.observeAnnotationControls();
    jQuery.initializeAnnotations();
    jQuery('#annotate-selection').button({icons: {primary: 'ui-icon-lightbulb'}});
//    jQuery('#excerpt-selection').button({icons: {primary: 'ui-icon-scissors'}});
    jQuery(".undo-button").button({icons: {primary: 'ui-icon-arrowreturnthick-1-w'}});
    jQuery.observeUndo();

    jQuery(".tagging-autofill-layers").live('click',function(){
      jQuery(this).tagSuggest({
        url: jQuery.rootPath() + 'annotations/autocomplete_layers',
        separator: ',',
        delay: 500
      });
    });

/*    
    var checkCount = function(clickCount){
      if(clickCount==1) {
        alert('single');
      }
      if(clickCount==2) {
        alert('double');
      }
      if(clickCount==3) {
        alert('triple');
      }
      clickCount=0;
    }

    var count = 0;
    jQuery('p').click(function(e){
      alert(jQuery(this).attr('id'));
      clearTimeout(timer);
      count++;
      timer = setTimeout(checkCount(count),300);
    });
*/

});
