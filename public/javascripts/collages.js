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
  var range = null;
  if((anchorNode === focusNode)){
    //Everything happens in a single node.
    if(anchorNode.nodeName == '#text'){
      //This is a selection in the same node and it isn't the entire node.
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

  if((anchor_x_path.match(/annotatable\-content/) && focus_x_path.match(/annotatable\-content/)) && (anchorString != focusString)){
    return {anchor_x_path: anchor_x_path, anchor_sibling_offset: anchor_sibling_offset, anchor_offset: anchor_offset, focus_x_path: focus_x_path, focus_sibling_offset: focus_sibling_offset, focus_offset: focus_offset}
  } else {
    throw 'It looks like you didn\'t select something, or you selected something that can\'t be annotated or excerpted.';
  }
},

storeRange: function(rangeObj){
  jQuery.ajax({
    type: 'POST',
    url: jQuery.rootPath() + 'excerpts/create',
    data: rangeObj,
    beforeSend: function(){jQuery('#spinner_block').show()},
    success: function(html){
      jQuery('#spinner_block').hide();
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
  try{
    var range = document.createRange();
    range.setStart((rangeObj.anchor_sibling_offset != null) ? anchorXPathNode.childNodes[rangeObj.anchor_sibling_offset] : anchorXPathNode,rangeObj.anchor_offset);
    range.setEnd((rangeObj.focus_sibling_offset != null) ? focusXPathNode.childNodes[rangeObj.focus_sibling_offset] : focusXPathNode,rangeObj.focus_offset);
  } catch (err){
    jQuery('div.ajax-error').show().html(err);
  }
  return range;
},

collapseRange: function(range){
  range.deleteContents();
  var node = document.createElement('span');
  node.appendChild(document.createTextNode('. . .'));
  node.className = 'excerpt';
  node.setAttribute('title', 'Click to expand');
  range.insertNode(node);
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

observe_excerpt_controls: function(){
  jQuery('#excerpt-selection').click(function(e){
    e.preventDefault();
    try{
      var rangeObj = jQuery.formatRange();
      if (window.console){
        console.log(rangeObj);
      }
      var range = jQuery.createRange(rangeObj);
      jQuery.storeRange(rangeObj);
      jQuery.collapseRange(range);
      if (window.console){
        console.log(range);
      }
    } catch(err) {
      jQuery('#ajax-error').show().html(err);
    }

  });
},
initialize_excerpts: function(){
  var collageId = jQuery('.collage-id').attr('id').split('-')[1];
  jQuery.ajax({
    type: 'GET',
    url: jQuery.rootPath() + 'collages/excerpts/' + collageId,
    cache: false,
    beforeSend: function(){jQuery('#spinner_block').show()},
    success: function(json){
      jQuery('#spinner_block').hide();
      jQuery(json).each(function(){
        var range = jQuery.createRange(this.excerpt);
        jQuery.collapseRange(range);
      });
    }
  });
},

insertAtClick: function(){
  jQuery("#annotatable-content [id*='n-']").click(function(e){
      console.log(e);
  });
}

});

jQuery(document).ready(function(){
    jQuery.observe_excerpt_controls();
    jQuery.initialize_excerpts();
//    jQuery.insertAtClick();
});
