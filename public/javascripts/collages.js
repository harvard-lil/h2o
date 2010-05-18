jQuery.extend({
checkRange: function(anchor_x_path,anchor_sibling_offset,anchor_offset,focus_x_path,focus_sibling_offset,focus_offset){
  // This may do some sanity checking in the future.
  var anchorString = [anchor_x_path, anchor_sibling_offset, anchor_offset].join('-');
  var focusString = [focus_x_path, focus_sibling_offset, focus_offset].join('-');

  if((anchor_x_path.match(/annotatable\-content/) && focus_x_path.match(/annotatable\-content/)) && (anchorString != focusString)){
    return {anchor_x_path: anchor_x_path, anchor_sibling_offset: anchor_sibling_offset, anchor_offset: anchor_offset, focus_x_path: focus_x_path, focus_sibling_offset: focus_sibling_offset, focus_offset: focus_offset}
  } else {
    throw 'It looks like you didn\'t select something, or you selected something that can\'t be annotated or excerpted.';
  }
},

createRange: function(rangeObj){
  var anchorXPathNode = jQuery.evalXPath(rangeObj.anchor_x_path);
  var focusXPathNode = jQuery.evalXPath(rangeObj.focus_x_path);
  try{
    var range = document.createRange();
    range.setStart((rangeObj.anchor_sibling_offset != null) ? anchorXPathNode.childNodes[rangeObj.anchor_sibling_offset] : anchorXPathNode,rangeObj.anchor_offset);
    range.setEnd((rangeObj.focus_sibling_offset != null) ? focusXPathNode.childNodes[rangeObj.focus_sibling_offset] : focusXPathNode,rangeObj.focus_offset);
    if(window.console){
      console.log('Before post');
      console.log(rangeObj);
    }
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
  } catch (err){
    alert(err);
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
    var sel = window.getSelection();
    var anchorNode = null;
    var anchor_offset = 0;
    var anchor_sibling_offset = 0;

    var focusNode = null;
    var focus_offset = 0;
    var focus_sibling_offset = 0;

    var range = null;

    if (window.console){
      console.log('Anchor Node Name: ' + sel.anchorNode.nodeName);
      console.log('Focus Node Name: ' + sel.focusNode.nodeName);
    }

    if((sel.anchorNode === sel.focusNode) ){
      //Everything happens in a single node.
      if(sel.anchorNode.nodeName == '#text'){
        //This is a selection in the same node and it isn't the entire node.
        if (window.console){
          console.log('You have selected part of a singular node');
        }
        anchorNode = sel.anchorNode;
        anchor_offset = sel.anchorOffset;
        focusNode = sel.anchorNode;
        focus_offset = sel.focusOffset;

        var anchor_x_path = '/' + jQuery.getXPath(anchorNode).join('/'); 

        if (window.console){
          console.log('Anchor Node:' + anchorNode + ' anchor_offset:' + anchor_offset + ' focusNode: ' + focusNode + ' focus_offset: ' + focus_offset);
        }
        for(var i=0; i <= sel.anchorNode.parentNode.childNodes.length; i++){
          if(sel.anchorNode.parentNode.childNodes[i] == sel.anchorNode){
            anchor_sibling_offset = i;
          }
        }

        try{
          var rangeObj = jQuery.checkRange(anchor_x_path,anchor_sibling_offset,anchor_offset,anchor_x_path,anchor_sibling_offset,focus_offset);
          if (window.console){
            console.log(rangeObj);
          }
          var range = jQuery.createRange(rangeObj);
          jQuery.collapseRange(range);
        } catch(err){
          alert(err);
          jQuery('#ajax-error').show().html(err);
        }

      } else if(sel.focusOffset == sel.anchorNode.childNodes.length){
        //They have selected an entire node, singularly.
        if (window.console){
          console.log('You have selected an entire node- just one.');
        }
        anchorNode = sel.anchorNode;
        anchor_offset = sel.anchorOffset;
        focusNode = sel.focusNode;
        focus_offset = sel.focusOffset;
        if (window.console){
          console.log('Anchor Node:' + anchorNode + ' anchor_offset:' + anchor_offset + ' focusNode: ' + focusNode + ' focus_offset: ' + focus_offset);
        }

        var anchor_x_path = '/' + jQuery.getXPath(anchorNode).join('/');
        try{
          var rangeObj = jQuery.checkRange(anchor_x_path,null,0,anchor_x_path,null,focus_offset);
          var range = jQuery.createRange(rangeObj);
          if (window.console){
            console.log("Synthetic Range:");
            console.log(range);
            console.log(rangeObj);
          }
          jQuery.collapseRange(range);
        } catch(err){
          alert(err);
          jQuery('#ajax-error').show().html(err);
        }
      } else {
        // It's in a single node but spans multiple siblings.
        anchorNode = sel.anchorNode;
        anchor_sibling_offset = sel.anchorOffset;
        focusNode = sel.focusNode;
        focus_sibling_offset = sel.focusOffset;

        if (window.console){
          console.log('Single node spanning multiple siblings');
          console.log('Anchor Node:' + anchorNode + ' anchor_offset:' + anchor_offset + ' focusNode: ' + focusNode + ' focus_offset: ' + focus_offset);
        }

        var anchor_x_path = '/' + jQuery.getXPath(anchorNode).join('/');
        try{
          var rangeObj = jQuery.checkRange(anchor_x_path,anchor_sibling_offset,0,anchor_x_path,focus_sibling_offset,0);
          var range = jQuery.createRange(rangeObj);
          if (window.console){
            console.log("Synthetic Range:");
            console.log(range);
            console.log(rangeObj);
          }
          jQuery.collapseRange(range);
        } catch(err){
          alert(err);
          jQuery('#ajax-error').show().html(err);
        }
      }
    } else {
      // This is a selection that spans nodes
      if (window.console){
        console.log('This selection spans nodes');
      }
      anchorNode = sel.anchorNode;
      anchor_offset = sel.anchorOffset;
      anchor_sibling_offset = 0;
      focusNode = sel.focusNode;
      focus_offset = sel.focusOffset;
      focus_sibling_offset = 0;

      for(var i=0; i <= sel.anchorNode.parentNode.childNodes.length; i++){
        if(sel.anchorNode.parentNode.childNodes[i] == sel.anchorNode){
          anchor_sibling_offset = i;
        }
      }
 
      for(var i=0; i <= sel.focusNode.parentNode.childNodes.length; i++){
        if(sel.focusNode.parentNode.childNodes[i] == sel.focusNode){
          focus_sibling_offset = i;
        }
      }

      var anchor_x_path = '/' + jQuery.getXPath(anchorNode).join('/'); 
      var focus_x_path = '/' + jQuery.getXPath(focusNode).join('/');

      try{
        var rangeObj = jQuery.checkRange(anchor_x_path,anchor_sibling_offset,anchor_offset,focus_x_path,focus_sibling_offset,focus_offset);
        if (window.console){
          console.log(rangeObj);
        }
        var range = jQuery.createRange(rangeObj);
        jQuery.collapseRange(range);
        if (window.console){
          console.log(range);
        }
      } catch(err) {
        alert(err);
        jQuery('#ajax-error').show().html(err);
      }
    }
  //      myRangeObj = {anchorNode: anchorNode, anchor_offset: anchor_offset, anchor_sibling_offset: anchor_sibling_offset, focusNode: focusNode, focus_offset: focus_offset, focus_sibling_offset: focus_sibling_offset};
  //      console.log(myRangeObj);
  });
}
});

jQuery(document).ready(function(){
    jQuery.observe_excerpt_controls();
});
