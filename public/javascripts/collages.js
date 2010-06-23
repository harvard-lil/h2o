jQuery.extend({

addLayerToCookie: function(cookieName,layerId){
  var currentVals = jQuery.unserializeHash(jQuery.cookie(cookieName));
  currentVals[layerId] = 1;
  var cookieVal = jQuery.serializeHash(currentVals);
  jQuery.cookie(cookieName, cookieVal, {expires: 365});
},

submitAnnotation: function(){
  var collageId = jQuery('.collage-id').attr('id').split('-')[1];
  jQuery('#annotation-form form').ajaxSubmit({
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
      jQuery('#annotation-form').dialog('close');
      if(window.console){
        console.log("Annotation object is:");
        console.log(response.annotation);
      }
      document.location = jQuery.rootPath() + 'collages/' + collageId;
    }
  });
},

removeLayerFromCookie: function(cookieName,layerId){
  var currentVals = jQuery.unserializeHash(jQuery.cookie(cookieName));
  delete currentVals[layerId];
  var cookieVal = jQuery.serializeHash(currentVals);
  jQuery.cookie(cookieName,cookieVal,{expires: 365});
},

annotateRange: function(obj){
  var start = obj.annotation_start.substring(1);
  var end = obj.annotation_end.substring(1);
  var points = [parseInt(start), parseInt(end)];
  var elStart = points[0];
  var elEnd = points[1];
  var i = 0;
  var ids = [];
  for(i = elStart; i <= elEnd; i++){
    ids.push('#t' + i);
  }
  var activeLayers = jQuery.unserializeHash(jQuery.cookie('active-layer-ids'));
  var hasActiveLayer = false;
  var layerNames = [];
  var lastLayerId = 0;
  jQuery(obj.layers).each(function(){
    layerNames.push(this.name);
    if(activeLayers[this.id] == 1){
      hasActiveLayer = true;
    }
    lastLayerId = this.id;
  });

  var startNode = jQuery('<span class="annotation-control" title="Click to see Annotation"></span>');
  jQuery(startNode).html(layerNames.join(', '));
  jQuery(startNode).addClass('c' + (lastLayerId % 10));
  jQuery(startNode).attr('id', 'annotation-control-' + obj.id + '-start');
  jQuery("#t" + elStart).before(startNode);

  var endNode = jQuery('<span class="annotation-control" title="Click to see Annotation"></span>');
  jQuery(endNode).html(layerNames.join(', '));
  jQuery(endNode).addClass('c' + (lastLayerId % 10));
  jQuery(endNode).attr('id', 'annotation-control-' + obj.id + '-end');

  jQuery("#t" + elEnd).after(endNode);

  var idList = ids.join(',');

  jQuery("#annotation-control-" + obj.id + "-start").button({icons: {primary: 'ui-icon-script', secondary: 'ui-icon-arrowthick-1-e'}}).bind({
    click: function(e){
      jQuery.annotationButton(e,obj.id,ids);
    },
    mouseover: function(e){
      if(! hasActiveLayer){
        jQuery('.a' + obj.id).css('background-color','yellow');
      }
    },
    mouseout: function(e){
      if(! hasActiveLayer){
        jQuery('.a' + obj.id).css('background-color', '#ffffff');
      }
    }
  });
  jQuery("#annotation-control-" + obj.id + "-end").button({icons: {primary: 'ui-icon-arrowthick-1-w'}}).bind({
    click: function(e){
      jQuery.annotationButton(e,obj.id,ids)
    },
    mouseover: function(e){
      if(! hasActiveLayer){
        jQuery('.a' + obj.id).css('background-color','yellow');
      }
    },
    mouseout: function(e){
      if(! hasActiveLayer){
        jQuery('.a' + obj.id).css('background-color', '#ffffff');
      }
    }
  });

},

annotationButton: function(e,annotationId,ids){
  e.preventDefault();
  var collageId = jQuery('.collage-id').attr('id').split('-')[1];
  if(jQuery('#annotation-details-' + annotationId).length == 0){
    jQuery.ajax({
      type: 'GET',
      cache: false,
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
          height: 500,
          title: 'Annotation Details',
          width: 600,
          position: [e.clientX,e.clientY - 330],
            buttons: {
              Close: function(){
                jQuery(this).dialog('close');
              },
              Delete: function(){
                if(confirm('Are you sure?')){
                  jQuery.ajax({
                    cache: false,
                    type: 'POST',
                    data: {'_method': 'delete'},
                    url: jQuery.rootPath() + 'annotations/destroy/' + annotationId,
                    beforeSend: function(){
                      jQuery('#spinner_block').show();
                      jQuery.showPleaseWait();
                    },
                    error: function(xhr){
                      jQuery('#spinner_block').hide();
                      jQuery('div.ajax-error').show().append(xhr.responseText);
                    },
                    success: function(response){
                      jQuery('#annotation-details-' + annotationId).dialog('close');
                      document.location = jQuery.rootPath() + 'collages/' + collageId;
                    },
                    complete: function(){
                      jQuery('#please-wait').dialog('close');
                    }
                  });
                }
              },
              Edit: function(){
                jQuery(this).dialog('close');
                jQuery.ajax({
                  type: 'GET',
                  cache: false,
                  url: jQuery.rootPath() + 'annotations/edit/' + annotationId,
                  beforeSend: function(){
                    jQuery('#spinner_block').show();
                    jQuery('#new-annotation-error').html('').hide();
                  },
                  error: function(xhr){
                    jQuery('#spinner_block').hide();
                    jQuery('#new-annotation-error').show().append(xhr.responseText);
                  },
                  success: function(html){
                    jQuery('#spinner_block').hide();
                    jQuery('#annotation-form').html(html);
                    jQuery.updateAnnotationPreview(collageId);
                    jQuery('#annotation-form').dialog({
                      bgiframe: true,
                      minWidth: 600,
                      width: 800,
                      modal: true,
                      title: 'Edit Annotation',
                      buttons: {
                        'Save': function(){
                          jQuery.submitAnnotation();
                        },
                        Cancel: function(){
                          jQuery('#new-annotation-error').html('').hide();
                          jQuery(this).dialog('close');
                        }
                      }
                    });
                  }
                });
              }
            }
        });
      }
    });
  } else {
    jQuery('#annotation-details-' + annotationId).dialog('open');
  }
},

showPleaseWait: function(){
  jQuery('#please-wait').dialog({
    closeOnEscape: false,
    draggable: false,
    modal: true,
    resizable: false,
    autoOpen: true
 });
},

initializeAnnotations: function(){
  // This iterates through the annotations on this collage and emits the controls.
  var collageId = jQuery('.collage-id').attr('id').split('-')[1];
  jQuery.ajax({
    type: 'GET',
    url: jQuery.rootPath() + 'collages/annotations/' + collageId,
    cache: false,
    beforeSend: function(){
      jQuery('#spinner_block').show();
      jQuery.showPleaseWait();
      jQuery('div.ajax-error').html('').hide();
    },
    success: function(json){
      jQuery(json).each(function(){
        jQuery.annotateRange(this.annotation);
      });
      jQuery.observeWords();
//      jQuery('#spinner_block').hide();
    },
    complete: function(){
      jQuery('#please-wait').dialog('close');
    },
    error: function(xhr){
      jQuery('#spinner_block').hide();
      jQuery('div.ajax-error').show().append(xhr.responseText);
    }

  });
},

initLayers: function(){
  // This sets up the layer controls. Constructing nodes should be offloaded to the server. . . 
  var collageId = jQuery('.collage-id').attr('id').split('-')[1];
  jQuery.ajax({
    type:'GET',
    url: jQuery.rootPath() + 'collages/layers/' + collageId,
    cache: false,
    beforeSend: function(){
      jQuery('#spinner_block').show();
      jQuery('div.ajax-error').html('').hide();
      jQuery('#view-layer-list').html('');
    },
    success: function(json){
      jQuery('#spinner_block').hide();
      var output = '';
      var viewTagList = jQuery('#view-layer-list');
      var activeLayers = jQuery.unserializeHash(jQuery.cookie('active-layer-ids'));
      jQuery(json).each(function(){
        var checkboxNode = jQuery('<input type="checkbox" id="layer-checkbox-' + this.tag.id + '" class="layer-control" />');
        var node = jQuery('<span class="layer-control"></span>');
        node.addClass('c' + (this.tag.id % 10));
        if(activeLayers[this.tag.id] == 1){
          node.addClass('layer-active');
          jQuery(checkboxNode).attr('checked', true);
        }
        var anchor = jQuery('<a>');
        anchor.attr('href', jQuery.rootPath() + 'collages/' + collageId);
        anchor.html(this.tag.name);

        node.html(anchor);
        viewTagList.append(checkboxNode);
        viewTagList.append(node);
      });
      jQuery('.layer-control').click(function(e){
        e.preventDefault();
        var layerId = jQuery(this).attr('id').split('-')[2];
        jQuery('.layer-control').removeClass('layer-active');
        if(jQuery('#layer-checkbox-' + layerId).is(':checked')){
          // Set the name and id of the active layers.
          jQuery.addLayerToCookie('active-layer-ids',layerId);
          jQuery.addLayerToCookie('active-layer-names',jQuery(this).find('a').html());
          jQuery(this).addClass('layer-active');
        } else {
          jQuery.removeLayerFromCookie('active-layer-ids',layerId);
          jQuery.removeLayerFromCookie('active-layer-names',jQuery(this).find('a').html());
        }
        document.location = jQuery.rootPath() + 'collages/' + collageId;
      });
    },
    error: function(xhr){
      jQuery('#spinner_block').hide();
      jQuery('div.ajax-error').show().append(xhr.responseText);
    }
  });
},

updateAnnotationPreview: function(collageId){
  jQuery("#annotation-form form").observeForm(5,function(){
    jQuery.ajax({
      cache: false,
      type: 'POST',
      url: jQuery.rootPath() + 'annotations/annotation_preview',
      data: {preview: jQuery('#annotation_annotation').val(), collage_id: collageId},
      success: function(html){
        jQuery('#annotation_preview').html(html);
      }
    });
  });
},

wordEvent: function(e){
    if(e.type == 'mouseover'){
      jQuery(this).css('background-color','yellow')
    }
    if(e.type == 'mouseout'){
      jQuery(this).css('background-color', '#ffffff');
    } else if(e.type == 'click'){
      e.preventDefault();
      if(jQuery('#new-annotation-start').html().length > 0){
        // Set end point and annotate.
        jQuery('#new-annotation-end').html(jQuery(this).attr('id'));
        var collageId = jQuery('.collage-id').attr('id').split('-')[1];
        jQuery('#annotation-form').dialog({
          bgiframe: true,
          autoOpen: false,
          minWidth: 600,
          width: 800,
          modal: true,
          title: 'New Annotation',
          buttons: {
            'Save': function(){
              jQuery.submitAnnotation();
            },
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
          data: {collage_id: collageId, annotation_start: jQuery('#new-annotation-start').html(), annotation_end: jQuery('#new-annotation-end').html()},
          cache: false,
          beforeSend: function(){
            jQuery('#spinner_block').show();
            jQuery('div.ajax-error').html('').hide();
         },
          success: function(html){
            jQuery('#spinner_block').hide();
            jQuery('#annotation-form').html(html);
            jQuery('#annotation-form').dialog('open');
            jQuery.updateAnnotationPreview(collageId);
            if(jQuery('#annotation_layer_list').val() == ''){
              //FIXME - Ideally, we'd set this to the last layer that's been clicked. 
              jQuery('#annotation_layer_list').val(jQuery.cookie('active-layer-name'));
            }
          },
          error: function(xhr){
            jQuery('#spinner_block').hide();
            jQuery('div.ajax-error').show().append(xhr.responseText);
          }
        });
        jQuery('#new-annotation-start').html('');
        jQuery('#new-annotation-end').html('');
      } else {
        // Set start point
        jQuery('#new-annotation-start').html(jQuery(this).attr('id'));
      }
    }
  },

observeWords: function(){
  // This is a significant burden in that it binds to every "word node" on the page, so running it must
  // align with the rights a user has to this collage, otherwise we're just wasting cpu cycles. Also
  // the controller enforces privs - so feel free to fiddle with the DOM, it won't get you anywhere.

  // jQuery('tt:visible') as a query is much less efficient - unfortunately.
  
  if(jQuery('#is_owner').html() == 'true'){
    jQuery('tt').bind('mouseover mouseout click', jQuery.wordEvent);
  }
}

});

jQuery(document).ready(function(){
  jQuery('.button').button();
  if(jQuery('.collage-id').length > 0){
    jQuery.initLayers();
    jQuery.initializeAnnotations();
    jQuery(".tagging-autofill-layers").live('click',function(){
      jQuery(this).tagSuggest({
        url: jQuery.rootPath() + 'annotations/autocomplete_layers',
        separator: ',',
        delay: 500
      });
    });
  }
});
