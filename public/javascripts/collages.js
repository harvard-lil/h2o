jQuery.extend({

/*
collapseRange: function(range,obj){
  range.extractContents();
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
*/

annotateRange: function(range,obj){
  var activeLayerId = jQuery.cookie('active-layer-id');
  var hasActiveLayer = false;
  // alert("Annotation Id:" + obj.id);
  jQuery(obj.layers).each(function(){
      //alert(this.id);
      if(this.id == activeLayerId){
        hasActiveLayer = true;
      }
  });

  if(hasActiveLayer){
    //alert('A part of this layer.');
    range.deleteContents();
  } else {
//    alert('Not a part of this layer. . . hrm.');
  //  range.extractContents();
 //   alert(node);
  }
  var node = document.createElement('span');

  node.className = 'annotation-control';
  node.setAttribute('id', 'annotation-control-' + obj.id);
  node.setAttribute('title', 'Click to see annotation');
  node.appendChild(document.createTextNode(' - '));

  if(window.console){
    console.log('trying to insert annotation');
    console.log(node);
    console.log("Active Layer");
    console.log(activeLayerId);
  }

  range.insertNode(node);

  jQuery("#annotation-control-" + obj.id).button({icons: {primary: 'ui-icon-script'}}).click(function(e){
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

observeAnnotationControls: function(){
  jQuery('#annotate-selection').click(function(e){
    var rangeObj = jQuery.formatRange();
    var collageId = jQuery('.collage-id').attr('id').split('-')[1];
    rangeObj['collage_id'] = collageId;
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
        //alert('Initializing annotations:' + this.annotation.id);
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
      jQuery('#view-layer-list').html('');
      jQuery('#add-layer-list').html('');
    },
    success: function(json){
      jQuery('#spinner_block').hide();
      var output = '';
      var viewTagList = jQuery('#view-layer-list');
      var addTagList = jQuery('#add-layer-list');
      var activeLayerId = jQuery.cookie('active-layer-id');
      jQuery(json).each(function(){
        var node = jQuery('<span></span>');
        node.addClass('layer-control');
        node.attr('tag_id',this.tag.id);
        if(this.tag.id == activeLayerId){
          node.addClass('layer-active');
        }
        var anchor = jQuery('<a>');
        anchor.attr('href', jQuery.rootPath() + 'collages/' + collageId);
        anchor.html(this.tag.name);

        node.html(anchor);
        viewTagList.append(node);
        addTagList.append(jQuery(node).clone());
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
        var start = jQuery('#new-annotation-start').html().substring(1);
        var end = jQuery('#new-annotation-end').html().substring(1);
        var points = [parseInt(start), parseInt(end)];
        points.sort(function(a,b){return a - b});
        var elStart = points[0];
        var elEnd = points[1];
        var i = 0;
        var ids = [];
        for(i = elStart; i <= elEnd; i++){
          ids.push('#t' + i);
        }

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
              jQuery(ids.join(',')).css({display: 'none'});
              /* var range = jQuery.createRange(response.annotation);
              jQuery.annotateRange(range,response.annotation); */
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
//    jQuery.observeExcerptControls();
//    jQuery.initializeExcerpts();
    jQuery.initLayers();
    jQuery.observeAnnotationControls();
    jQuery.initializeAnnotations();
    jQuery('#annotate-selection').button({icons: {primary: 'ui-icon-lightbulb'}});
//    jQuery('#excerpt-selection').button({icons: {primary: 'ui-icon-scissors'}});
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
