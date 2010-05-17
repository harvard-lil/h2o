jQuery.extend({
storeRange: function(anchorXPath,anchorSiblingOffset,anchorOffset,focusXPath,focusSiblingOffset,focusOffset){
  //This will end up doing a POST.
  return {anchorXPath: anchorXPath, anchorSiblingOffset: anchorSiblingOffset, anchorOffset: anchorOffset, focusXPath: focusXPath, focusSiblingOffset: focusSiblingOffset, focusOffset: focusOffset}
},

createRange: function(rangeObj){
  var anchorXPathNode = jQuery.evalXPath(rangeObj.anchorXPath);
  var focusXPathNode = jQuery.evalXPath(rangeObj.focusXPath);
  var range = document.createRange();
  range.setStart(anchorXPathNode.childNodes[rangeObj.anchorSiblingOffset],rangeObj.anchorOffset);
  range.setEnd(focusXPathNode.childNodes[rangeObj.focusSiblingOffset],rangeObj.focusOffset);
  return range;
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
}
});


