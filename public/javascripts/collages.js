jQuery.extend({

annotateRange: function(obj){
  var start = obj.annotation_start.substring(1);
  var end = obj.annotation_end.substring(1);
  var points = [parseInt(start), parseInt(end)];
  points.sort(function(a,b){return a - b});
  var elStart = points[0];
  var elEnd = points[1];
  var i = 0;
  var ids = [];
  for(i = elStart; i <= elEnd; i++){
    ids.push('#t' + i);
  }

  var activeLayerId = jQuery.cookie('active-layer-id');
  var hasActiveLayer = false;
  var layerNames = [];
  var lastLayerId = 0;
  jQuery(obj.layers).each(function(){
    layerNames.push(this.name);
    if(this.id == activeLayerId){
      hasActiveLayer = true;
    }
    lastLayerId = this.id;
  });

  var startNode = jQuery('<span class="annotation-control" title="Click to see Annotation"></span>');
  jQuery(startNode).html(layerNames.join(', '));
  jQuery(startNode).addClass('c' + (lastLayerId % 10));
  jQuery(startNode).attr('id', 'annotation-control-' + obj.id + '-start');
  jQuery("#t" + elStart).before(startNode);
  jQuery("#t" + elStart)[0].innerHTML = jQuery("#t" + elStart)[0].innerHTML + '<span class="layer-boundary-' + obj.id + '">';

  var endNode = jQuery('<span class="annotation-control" title="Click to see Annotation"></span>');
  jQuery(endNode).html(layerNames.join(', '));
  jQuery(endNode).addClass('c' + (lastLayerId % 10));
  jQuery(endNode).attr('id', 'annotation-control-' + obj.id + '-end');

  jQuery("#t" + elEnd).after(endNode);

  jQuery("#t" + elEnd)[0].innerHTML = jQuery("#t" + elEnd)[0].innerHTML + '</span>';

  var idList = ids.join(',');

//  jQuery(idList).addClass('l' + obj.id);
  if(hasActiveLayer){
    jQuery(idList).css({display: 'none'});
  }

  jQuery("#annotation-control-" + obj.id + "-start").button({icons: {primary: 'ui-icon-script', secondary: 'ui-icon-arrowthick-1-e'}}).bind({
    click: function(e){
      jQuery.annotationButton(e,obj.id,ids);
    },
    mouseover: function(e){
      jQuery('.a' + obj.id).css('background-color','yellow');
    },
    mouseout: function(e){
      jQuery('.a' + obj.id).css('background-color', '#ffffff');
    }
  });
  jQuery("#annotation-control-" + obj.id + "-end").button({icons: {primary: 'ui-icon-script', secondary: 'ui-icon-arrowthick-1-w'}}).bind({
    click: function(e){
      jQuery.annotationButton(e,obj.id,ids)
    },
    mouseover: function(e){
      jQuery('.a' + obj.id).css('background-color','yellow');
    },
    mouseout: function(e){
      jQuery('.a' + obj.id).css('background-color', '#ffffff');
    }
  });

},

annotationButton: function(e,annotationId,ids){
  e.preventDefault();
//  var annotationId = jQuery(this).attr('id').split('-')[2];
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
          height: 300,
          title: 'Annotation Details',
          width: 400,
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
                      jQuery('#annotation-control-' + annotationId + '-start').remove();
                      jQuery('#annotation-control-' + annotationId + '-end').remove();
                      jQuery(ids.join(',')).show();
                      jQuery('#annotation-details-' + annotationId).dialog('close');
                      jQuery.initLayers();
                    },
                    complete: function(){
                      jQuery('#please-wait').dialog('close');
                    }
                  });
                }
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
      var activeLayerId = jQuery.cookie('active-layer-id');
      jQuery(json).each(function(){
        var node = jQuery('<span class="layer-control"></span>');
        node.attr('tag_id',this.tag.id);
        node.addClass('c' + (this.tag.id % 10));
        if(this.tag.id == activeLayerId){
          node.addClass('layer-active');
        }
        var anchor = jQuery('<a>');
        anchor.attr('href', jQuery.rootPath() + 'collages/' + collageId);
        anchor.html(this.tag.name);

        node.html(anchor);
        viewTagList.append(node);
      });
      jQuery('.layer-control').click(function(){
          var layerId = jQuery(this).attr('tag_id');
          jQuery('.layer-control').removeClass('layer-active');
          // Set the name and id of the active layer.
          jQuery.cookie('active-layer-id',layerId,{expires: 365});
          jQuery.cookie('active-layer-name',jQuery(this).find('a').html(), {expires: 365});
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
},

observeWords: function(){
  jQuery('tt').bind({
    mouseover: function(){
      jQuery(this).css('background-color','yellow')
    },
    mouseout: function(){
      jQuery(this).css('background-color', '#ffffff');
    },
    click: function(e){
      e.preventDefault();
      if(jQuery('#new-annotation-start').html().length > 0){
        // Set end point
        jQuery('#new-annotation-end').html(jQuery(this).attr('id'));
        var collageId = jQuery('.collage-id').attr('id').split('-')[1];
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
              if(window.console){
                console.log("Annotation object is:");
                console.log(response.annotation);
              }
              // Do UI decoration here.
              jQuery.annotateRange(response.annotation);
              jQuery.initLayers();
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
          data: {collage_id: collageId, annotation_start: jQuery('#new-annotation-start').html(), annotation_end: jQuery('#new-annotation-end').html()},
          cache: false,
          beforeSend: function(){
            jQuery('#spinner_block').show();
            jQuery('div.ajax-error').html('').hide();
         },
          success: function(html){
            jQuery('#spinner_block').hide();
            jQuery('#new-annotation-form').html(html);
            jQuery('#new-annotation-form').dialog('open');
            if(jQuery('#annotation_layer_list').val() == ''){
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
  });
}

});

jQuery(document).ready(function(){
    jQuery.initLayers();
    jQuery.initializeAnnotations();
    jQuery('#annotate-selection').button({icons: {primary: 'ui-icon-lightbulb'}});
    jQuery(".undo-button").button({icons: {primary: 'ui-icon-arrowreturnthick-1-w'}});
    jQuery.observeUndo();
    jQuery.observeWords();

    jQuery(".tagging-autofill-layers").live('click',function(){
      jQuery(this).tagSuggest({
        url: jQuery.rootPath() + 'annotations/autocomplete_layers',
        separator: ',',
        delay: 500
      });
    });


});
