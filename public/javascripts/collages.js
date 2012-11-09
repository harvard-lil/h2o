var new_annotation_start = '';
var new_annotation_end = '';
var just_hidden = 0;
var layer_info = {};
var last_annotation = 0;
var highlight_history = {};
var annotation_position = 0;
var head_offset;
var heatmap;

jQuery.extend({
  scaleOpacity: function() {
    var max_children = 0;
    jQuery.each(jQuery('.special_highlight'), function(i, el) {
      if(jQuery(el).children().size() > max_children) {
        max_children = jQuery(el).children().size();
      }
    });
    jQuery('.special_highlight tt').css({ 'opacity' : 0.50/max_children });
  },
  getHexes: function() {
    var hexes = jQuery('<div class="hexes"></div>');
    jQuery.each(color_map, function(i, el) {
      var node = jQuery('<a href="#"></a>').data('value', el).css('background', '#' + el);
      if(jQuery(".layer_check [data-value='" + el + "']").length) {
        node.addClass('inactive');
      }
      hexes.append(node);
    });
    if(hexes.find('a').length == hexes.find('a.inactive').length) {
      hexes.find('a.inactive').removeClass('inactive');
    }
    return hexes;
  },
  initializeLayerColorMapping: function() {
    jQuery('.hexes a').live('click', function() {
      if(jQuery(this).hasClass('inactive')) {
        return false;
      }
      jQuery(this).parent().siblings('.hex_input').find('input').val(jQuery(this).data('value'));
      jQuery(this).siblings('a.active').removeClass('active');
      jQuery(this).addClass('active');
      return false;
    });
    jQuery('#add_new_layer').live('click', function() {
      var new_layer = jQuery('<div class="new_layer"><p>LAYER: <input type="text" name="new_layer_list[]layer]" /></p><p class="hex_input">HEX:<input type="hidden" name="new_layer_list[][hex]" /></p><a href="#" class="remove_layer">- REMOVE</a></div>');
      var hexes = jQuery.getHexes();
      hexes.insertBefore(new_layer.find('.remove_layer'));
      jQuery('#new_layers').append(new_layer);
      return false;
    });
    jQuery('.remove_layer').live('click', function() {
      jQuery(this).parent().remove();
      return false;
    });
  },
  initializeHeatmap: function() {
    jQuery('#hide_heatmap').hide();
    jQuery('#show_heatmap').click(function() {
      if(jQuery(this).hasClass('inactive')) {
        return false;
      }
      jQuery.ajax({
        type: 'GET',
        cache: false,
        dataType: 'JSON',
        url: jQuery.rootPath() + 'collages/' + jQuery.getItemId() + '/heatmap',
        beforeSend: function(){
          jQuery.showGlobalSpinnerNode();
        },
        success: function(data){
          jQuery('.tools-popup .highlighted').click();
          heatmap = data.heatmap;
          jQuery.each(heatmap, function(i, e) {
            jQuery('tt#' + i).css('background-color', '#' + e);
            jQuery('#hide_heatmap').show();
            jQuery('#show_heatmap').hide();
          });
          jQuery.hideGlobalSpinnerNode();
        },
        error: function() {
          jQuery.hideGlobalSpinnerNode();
        }
      });
    });
    jQuery('#hide_heatmap').click(function() {
      if(jQuery(this).hasClass('inactive')) {
        return false;
      }
      jQuery.each(heatmap, function(i, e) {
        jQuery('tt#' + i).css('background-color', '#ffffff');
        jQuery('#show_heatmap').show();
        jQuery('#hide_heatmap').hide();
      });
    });
  },
  hideShowAnnotationOptions: function() {
    var total = jQuery('.annotation-content').size();
    var shown = jQuery('.annotation-content').filter(':visible').size();
    if(total == shown) {
      jQuery('#hide_annotations').show();
      jQuery('#show_annotations').hide();
    } else if(shown == 0) {
      jQuery('#hide_annotations').hide();
      jQuery('#show_annotations').show();
    } else {
      jQuery('#show_annotations,#hide_annotations').show();
    }
  },
  hideShowUnlayeredOptions: function() {
    var total = jQuery('.unlayered-ellipsis').size();
    var shown = jQuery('.unlayered-ellipsis').filter(':visible').size();
    if(total == shown) {
      jQuery('#hide_unlayered').hide();
      jQuery('#show_unlayered').show();
    } else if(shown == 0) {
      jQuery('#hide_unlayered').show();
      jQuery('#show_unlayered').hide();
    } else {
      jQuery('#show_unlayered,#hide_unlayered').show();
    }
  },
  addCommas: function(str) {
    str += '';
    x = str.split('.');
    x1 = x[0];
    x2 = x.length > 1 ? '.' + x[1] : '';
    var rgx = /(\d+)(\d{3})/;
    while(rgx.test(x1)) {
      x1 = x1.replace(rgx, '$1' + ',' + '$2');
    }
    return x1 + x2;
  },
  initializeFontChange: function() {  
    var val = jQuery.cookie('font_size');
    if(val != null) {
      jQuery('.font-size-popup select').val(val);
      jQuery('#collage article').css('font-size', parseInt(val) + 1 + 'px');
      jQuery('#description_less, #description_more, #description').css('font-size', (parseInt(val) + 2) + 'px');
      jQuery('#collage .details h5').css('font-size', parseInt(val) + 1 + 'px');
    }
    jQuery('.font-size-popup select').selectbox({
      className: "jsb", replaceInvisible: true 
    }).change(function() {
      var element = jQuery(this);
      jQuery.cookie('font_size', element.val(), { path: "/" });
      jQuery('#collage article').css('font-size', element.val() + 'px');
      jQuery('#description_less, #description_more, #description').css('font-size', (parseInt(element.val()) + 1) + 'px');
      jQuery('#collage .details h5').css('font-size', element.val() + 'px');
    });
    jQuery("#collage .description .buttons ul #fonts span").parent().click(function() { 
      jQuery('.font-size-popup').css({ 'top': 25 }).toggle();
      jQuery(this).toggleClass("btn-a-active");
      return false;
    });
  },
  initializeToolListeners: function () {
    jQuery("#collage .description .buttons ul #tools span").parent().click(function() { 
      jQuery('.tools-popup').css({ 'top': 25 }).toggle();
      jQuery(this).toggleClass("btn-a-active");
      return false;
    });
    jQuery('#layers li').each(function(i, el) {
      layer_info[jQuery(el).data('id')] = {
        'hex' : jQuery(el).data('hex'),
        'name' : jQuery(el).data('name')
      };
      jQuery('a.annotation-control-' + jQuery(el).data('id')).css('background', '#' + jQuery(el).data('hex'));
      jQuery(el).find('.link-o').css('background', '#' + jQuery(el).data('hex'));
    });
    jQuery('#author_edits').click(function(e) {
      e.preventDefault();
      if(jQuery(this).hasClass('inactive')) {
        return;
      }
      last_data = original_data;
      jQuery.loadState();
      jQuery('.layered-control,.unlayered-control').hide();
    });
    jQuery('#full_text').click(function(e) {
      e.preventDefault();
      var el = jQuery(this);
      jQuery.showGlobalSpinnerNode();
      jQuery('article p, article center').css('display', 'block');
      jQuery('article tt').css('display', 'inline');
      jQuery('.annotation-ellipsis').css('display', 'none');
      jQuery('#layers a.hide_show strong').html('HIDE');
      jQuery('#layers a').removeClass('shown');
      jQuery('article .unlayered-ellipsis').css('display', 'none');
      jQuery('article .unlayered-control').css('display', 'inline-block');
      jQuery.hideShowUnlayeredOptions();
      jQuery.hideGlobalSpinnerNode();
    });

    jQuery('#show_unlayered').click(function(e) {
      e.preventDefault();
      jQuery.showGlobalSpinnerNode();
      jQuery('article p.unlayered, article center.unlayered').css('display', 'block');
      jQuery('article tt.unlayered').css('display', 'inline');
      jQuery('article .unlayered-control').css('display', 'inline-block');
      jQuery('article .unlayered-ellipsis').css('display', 'none');
      jQuery.hideShowUnlayeredOptions();
      jQuery.hideGlobalSpinnerNode();
    });
    jQuery('#hide_unlayered').click(function(e) {
      e.preventDefault();
      jQuery.showGlobalSpinnerNode();
      jQuery('article .unlayered, article .unlayered-control').css('display', 'none');
      jQuery('article .unlayered-ellipsis').css('display', 'inline-block');
      jQuery.hideShowUnlayeredOptions();
      jQuery.hideGlobalSpinnerNode();
    });

    jQuery('#show_annotations').not('.inactive').click(function(e) {
      e.preventDefault();
      jQuery.showGlobalSpinnerNode();
      jQuery('.annotation-content').css('display', 'inline-block');
      jQuery.hideGlobalSpinnerNode();
      jQuery.hideShowAnnotationOptions();
    });
    jQuery('#hide_annotations').not('.inactive').click(function(e) {
      e.preventDefault();
      jQuery.showGlobalSpinnerNode();
      jQuery('.annotation-content').css('display', 'none');
      jQuery.hideGlobalSpinnerNode();
      jQuery.hideShowAnnotationOptions();
    });

    jQuery('#layers .hide_show').click(function(e) {
      e.preventDefault();
      jQuery.showGlobalSpinnerNode();

      var el = jQuery(this);
      var layer_id = el.parent().data('id');
      //Note: Toggle here was very slow 
      if(el.find('strong').html() == 'SHOW') {
        el.find('strong').html('HIDE');
        jQuery('article .' + layer_id).css('display', 'inline-block');
        jQuery('article tt.' + layer_id).css('display', 'inline').addClass('grey');
        jQuery('.annotation-ellipsis-' + layer_id).css('display', 'none');
        jQuery('.layered-control-' + layer_id).css('display', 'inline-block');
      } else {
        el.find('strong').html('SHOW');
        jQuery('article .' + layer_id + ',.ann-annotation-' + layer_id).css('display', 'none');
        jQuery('.annotation-ellipsis-' + layer_id).css('display', 'inline');
        jQuery('.layered-control-' + layer_id).hide();
      }
      jQuery.hideGlobalSpinnerNode();
    });

    jQuery('#layers .link-o').click(function(e) {
      e.preventDefault();
      var el = jQuery(this);
      var id = el.parent().data('id');
      if(jQuery('#hide_heatmap').is(':visible')) {
        jQuery('#hide_heatmap').click();
      }
      if(el.hasClass('highlighted')) {
        el.siblings('.hide_show').find('strong').html('HIDE');
        jQuery('article .' + id + ',.ann-annotation-' + id).css('display', 'inline-block');
        jQuery('article tt.' + id).css('display', 'inline');
        jQuery('.annotation-ellipsis-' + id).css('display', 'none');
        jQuery('tt.' + id + ' .special_highlight tt').remove();
        el.removeClass('highlighted').html('HIGHLIGHT');
      } else {
        el.siblings('.hide_show').find('strong').html('HIDE');
        jQuery('article .' + id + ',.ann-annotation-' + id).css('display', 'inline-block');
        jQuery('article tt.' + id).css('display', 'inline');
        jQuery('.annotation-ellipsis-' + id).css('display', 'none');

        var hex = '#' + layer_info[id].hex;
        jQuery.each(jQuery('tt.' + id + ' .special_highlight'), function(i, el) {
          var node = jQuery('<tt></tt>').css({ background: hex, 'opacity' : 0.25 }).addClass(id);
          jQuery(el).append(node);
          //if in read mode only
          jQuery(el).show();
        });
        el.addClass('highlighted').html('UNHIGHLIGHT');
      }
      jQuery.scaleOpacity();
    });
  
    jQuery("#edit-show").click(function(e) {
      e.preventDefault();
      var el = jQuery(this);
      if(el.html() == "READ") {
        el.html("EDIT"); 
        jQuery.unObserveWords();
        jQuery('.control-divider').css('display', 'none');
        jQuery('article tt.a').removeClass('edit_highlight');
        jQuery('.default-hidden,article tt.grey').css('color', '#666');
        jQuery('.layered-control,.unlayered-control').width(9).height(16);
        jQuery('#author_edits').removeClass('inactive');
        jQuery('#show_heatmap, #hide_heatmap').removeClass('inactive');
        jQuery('.special_highlight').show();

        /* Forcing an autosave to save in READ mode */
        var data = jQuery.retrieveState();  
        last_data = data;
        jQuery.recordCollageState(JSON.stringify(data), false);
      } else {
        el.html("READ");  
        jQuery.observeWords();
        jQuery('#author_edits').addClass('inactive');
        jQuery('.control-divider').css('display', 'inline-block');
        jQuery('article tt.a').addClass('edit_highlight');
        jQuery('.default-hidden,article tt.grey').css('color', '#000');
        jQuery('.layered-control,.unlayered-control').width(0).height(0);
        jQuery('#show_heatmap, #hide_heatmap').addClass('inactive');
        jQuery('.special_highlight').hide();
      }
      el.toggleClass('editing');
    });
  },
  initializePrintListeners: function() {
    jQuery('#print-container form').submit(function() {
      var data = jQuery.retrieveState();
  
      data.highlights = {};
      jQuery.each(jQuery('.special_highlight tt'), function(i, el) {
        data.highlights[jQuery(el).attr('class')] = layer_info[jQuery(el).attr('class')].hex;
      });

      jQuery('#state').val(JSON.stringify(data));
    });
  },
  recordCollageState: function(data, show_message) {
    var words_shown = jQuery('#collage article tt').filter(':visible').size();
    jQuery.ajax({
      type: 'POST',
      cache: false,
      data: {
        readable_state: data,
        words_shown: words_shown
      },
      url: jQuery.rootPath() + 'collages/' + jQuery.getItemId() + '/save_readable_state',
      success: function(results){
        if(show_message) {
          jQuery('#autosave').html('saved at ' + results.time).show().fadeOut(5000);
          jQuery('#word_count').html('Number of visible words: ' + jQuery.addCommas(words_shown) + ' out of ' + jQuery.addCommas(jQuery('#collage article tt').size())); 
        }
      }
    });
  },
  retrieveState: function() {
    var data = {};
    jQuery('.unlayered_start').each(function(i, el) {
      data['.unlayered_' + jQuery(el).attr('id').replace(/^t/, '')] = jQuery(el).css('display');  
    });
    jQuery('.unlayered-ellipsis').each(function(i, el) {
      data['#' + jQuery(el).attr('id')] = jQuery(el).css('display');  
    });
    jQuery('.annotation-ellipsis').each(function(i, el) {
      data['#' + jQuery(el).attr('id')] = jQuery(el).css('display');  
    });
    jQuery('.annotation-asterisk').each(function(i, el) {
      data['.a' + jQuery(el).data('id')] = jQuery(el).css('display');  
      data['#' + jQuery(el).attr('id')] = jQuery(el).css('display');
    });
    jQuery('.annotation-content').each(function(i, el) {
      if(jQuery(el).attr('id')) {
        data['#annotation-content-' + jQuery(el).attr('id').replace(/annotation-content-/, '')] = jQuery(el).css('display');  
      }
    });
    data.edit_mode = jQuery('#edit-show').html() == 'READ' ? true : false;
    return data;
  },
  listenToRecordCollageState: function() {
    setInterval(function(i) {
      var data = jQuery.retrieveState();  
      if(jQuery('#edit-show').html() == 'READ' && (JSON.stringify(data) != JSON.stringify(last_data))) {
        last_data = data;
        jQuery.recordCollageState(JSON.stringify(data), true);
      }
    }, 1000); 
  },
  loadState: function() {
    jQuery.each(last_data, function(i, e) {
      if(i.match(/\.a/) && e != 'none') {
        jQuery(i).css('display', 'inline');
      } else if(i.match(/\.unlayered/)) {
        if(e == 'none') {
          // if unlayered text default is hidden,
          // add wrapper nodes with arrow for collapsing text
          // here!
          jQuery(i).addClass('default-hidden').css('display', 'none');
        } else {
          jQuery('tt' + i).css('display', 'inline');
          jQuery('p' + i + ',center' + i).css('display', 'block');
        }
      } else {
        jQuery(i).css('display', e);
      }
    });
    if(last_data.edit_mode && access_results.can_edit_annotations) {
      jQuery('#edit-show').html("READ");  
      jQuery.observeWords();
      jQuery('.control-divider').css('display', 'inline-block');
      jQuery('article tt.a').addClass('edit_highlight');
      jQuery('.default-hidden').css('color', '#000');
      jQuery('.layered-control,.unlayered-control').width(0).height(0);
      jQuery('#hide_heatmap, #show_heatmap').addClass('inactive');
    } else {
       jQuery.unObserveWords();
    }
    jQuery('article').css('opacity', 1.0);
    if(jQuery.cookie('scroll_pos')) {
      jQuery(window).scrollTop(jQuery.cookie('scroll_pos'));
      jQuery.cookie('scroll_pos', null);
    }
    jQuery.hideShowUnlayeredOptions();
    jQuery.hideShowAnnotationOptions();
  }, 

  submitAnnotation: function(){
    var filtered = jQuery('#annotation_annotation').val().replace(/"/g, '&quot;');
    jQuery('#annotation_annotation').val(filtered);
    jQuery('#annotation-form form').ajaxSubmit({
      error: function(xhr){
        jQuery.hideGlobalSpinnerNode();
        jQuery('#new-annotation-error').show().append(xhr.responseText);
      },
      beforeSend: function(){
        jQuery.cookie('scroll_pos', annotation_position);
        jQuery.showGlobalSpinnerNode();
        jQuery('div.ajax-error').html('').hide();
        jQuery('#new-annotation-error').html('').hide();
      },
      success: function(response){
        jQuery.hideGlobalSpinnerNode();
        jQuery('#annotation-form').dialog('close');
        document.location.reload(true);
      }
    });
  },

  toggleAnnotation: function(id) {
    if(jQuery('#annotation-content-' + id).css('display') == 'inline-block') {
      jQuery('#annotation-content-' + id).css('display', 'none');
    } else {
      jQuery('#annotation-content-' + id).css('display', 'inline-block');
    }
  },

  annotationButton: function(annotationId){
    var collageId = jQuery.getItemId();
    if(jQuery('#annotation-details-' + annotationId).length == 0){
      jQuery.ajax({
        type: 'GET',
        cache: false,
        url: jQuery.rootPath() + 'annotations/' + annotationId,
        beforeSend: function(){
          jQuery.showGlobalSpinnerNode();
          jQuery('div.ajax-error').html('').hide();
        },
        error: function(xhr){
          jQuery.hideGlobalSpinnerNode();
          jQuery('div.ajax-error').show().append(xhr.responseText);
        },
        success: function(html){
          // Set up the annotation node to be loaded into a dialog
          jQuery.hideGlobalSpinnerNode();
          var node = jQuery(html);
          jQuery('body').append(node);
          var dialog = jQuery('#annotation-details-' + annotationId).dialog({
            height: 500,
            title: 'Annotation Details',
            width: 600,
            //position: [e.clientX,e.clientY - 330],
            buttons: {
              Close: function(){
                jQuery(this).dialog('close');
              },
              Delete: function(){
                if(confirm('Are you sure?')){
                  jQuery.ajax({
                    cache: false,
                    type: 'POST',
                    data: {
                      '_method': 'delete'
                    },
                    url: jQuery.rootPath() + 'annotations/destroy/' + annotationId,
                    beforeSend: function(){
                      jQuery.showGlobalSpinnerNode();
                    },
                    error: function(xhr){
                      jQuery.hideGlobalSpinnerNode();
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
                annotation_position = jQuery(window).scrollTop();
                jQuery(this).dialog('close');
                jQuery.ajax({
                  type: 'GET',
                  cache: false,
                  url: jQuery.rootPath() + 'annotations/edit/' + annotationId,
                  beforeSend: function(){
                    jQuery.showGlobalSpinnerNode();
                    jQuery('#new-annotation-error').html('').hide();
                  },
                  error: function(xhr){
                    jQuery.hideGlobalSpinnerNode();
                    jQuery('#new-annotation-error').show().append(xhr.responseText);
                  },
                  success: function(html){
                    jQuery.hideGlobalSpinnerNode();
                    jQuery('#annotation-form').html(html);
                    jQuery('#annotation-form').dialog({
                      bgiframe: true,
                      minWidth: 450,
                      width: 450,
                      modal: true,
                      title: 'Edit Annotation',
                      buttons: {
                        'Save': function(){
                          var values = new Array();
                          jQuery(".layer_check input").each(function(i, el) {
                            if(jQuery(el).attr('checked')) {
                              values.push(jQuery(el).data('value'));
                            }
                          });
                          jQuery.submitAnnotation();
                        },
                        Cancel: function(){
                          jQuery('#new-annotation-error').html('').hide();
                          jQuery(this).dialog('close');
                        }
                      }
                    });
                    var filtered = jQuery('#annotation_annotation').val().replace(/&quot;/g, '"');
                    jQuery('#annotation_annotation').val(filtered);
                    jQuery("#annotation_annotation").markItUp(h2oTextileSettings);
                  }
                });
              }
            }
          });

          jQuery('#annotation-tabs-' + annotationId).tabs();
          if(!access_results.can_edit_annotations) {
            jQuery('#annotation-details-' + annotationId).dialog('option','buttons',{
              Close: function(){
                jQuery(this).dialog('close');
              }
            });
          }
        }
      });
    } else {
      jQuery('#annotation-details-' + annotationId).dialog('open');
    }
  },

  initializeAnnotationListeners: function(){
    jQuery('.annotation-asterisk').tipsy({ gravity: 'sw', trigger: 'manual' });
    jQuery('.unlayered-ellipsis').click(function(e) {
      e.preventDefault();
      var id = jQuery(this).data('id');
      jQuery('tt.unlayered_' + id).css('display', 'inline');
      jQuery('p.unlayered_' + id + ',center.unlayered_' + id).css('display', 'block');
      jQuery('.unlayered-control-' + id).css('display', 'inline-block');
      jQuery(this).css('display', 'none');
      jQuery.hideShowUnlayeredOptions();
    });
    jQuery('.annotation-ellipsis').click(function(e) {
      e.preventDefault();
      var id = jQuery(this).data('id');
      jQuery('#annotation-control-' + id + ',#annotation-asterisk-' + id).css('display', 'inline-block');
      jQuery('article tt.a' + id).css('display', 'inline').addClass('grey');
      jQuery(this).css('display', 'none');
      jQuery('.layered-control-' + id).css('display', 'inline-block');
    });
    jQuery('.unlayered-control').click(function(e) {
      e.preventDefault();
      var id = jQuery(this).data('id');
      jQuery('.unlayered_' + id + ',.unlayered-control-' + id).css('display', 'none');
      jQuery('#unlayered-ellipsis-' + id).css('display', 'inline-block');
      jQuery.hideShowUnlayeredOptions();
    });
    jQuery('.layered-control').click(function(e) {
      e.preventDefault();
      var id = jQuery(this).data('id');
      jQuery('tt.a' + id + ',.layered-control-' + id).css('display', 'none');
      jQuery('#annotation-ellipsis-' + id).css('display', 'inline-block');
    });
  },
  initializeAnnotationOrCollage: function(){
    jQuery('#annotation-form').dialog({
      bgiframe: true,
      autoOpen: false,
      minWidth: 450,
      width: 450,
      modal: true,
      title: '',
      buttons: {
        'Save': function(){
          jQuery(this).dialog('close');
          var abstract_type = jQuery('input[name=abstract_type]:checked').val(); 
	      var new_annotation_start = jQuery('input[name=annotation_start]').val();
	      var new_annotation_end = jQuery('input[name=annotation_end]').val();
	      var collageId = jQuery('input[name=collage_id]').val();

          if (abstract_type == 'annotation'){
	        jQuery.openAnnotationDialog('annotations/new', {
		      collage_id: collageId,
			  annotation_start: new_annotation_start,
			  annotation_end: new_annotation_end});
          }
      	  else{
	        jQuery.openCollageLinkDialog('collage_links/embedded_pager', {
		      collage_id: collageId,
		      link_start: new_annotation_start,
			  link_end: new_annotation_end});
      	  }
        },
        'Cancel': function(){
          jQuery('#new-annotation-error').html('').hide();
          jQuery(this).dialog('close');
        }
     }
    }); 
  },

  wordEvent: function(e){
    var el = jQuery(this);
    if(e.type == 'mouseover'){
      el.addClass('annotation_start_highlight');
    }
    if(e.type == 'mouseout'){
      el.removeClass('annotation_start_highlight');
    } else if(e.type == 'click'){
      annotation_position = jQuery(window).scrollTop();
      e.preventDefault();
      if(new_annotation_start != '') {
        new_annotation_end = el.attr('id');
        var collageId = jQuery.getItemId();
		    jQuery("#annotation_or_collage_link").dialog({
		      bgiframe: true,
          autoOpen: false,
          minWidth: 450,
		      width: 450,
		      modal: true,
		      title: '',
            buttons: {
            'Ok': function(){
      		    jQuery(this).dialog('close');
        		    var abstract_type = jQuery('input[name=abstract_type]:checked').val(); 
  	            var new_annotation_start = jQuery('input[name=annotation_start]').val();
  	            var new_annotation_end = jQuery('input[name=annotation_end]').val();
  	            var collageId = jQuery('input[name=collage_id]').val();

                if (abstract_type == 'annotation'){
	                jQuery.openAnnotationDialog('annotations/new', {
  				          collage_id: collageId,
  			            annotation_start: new_annotation_start,
  				          annotation_end: new_annotation_end
				          });
      		      }
      		      else{
	    		        jQuery.openCollageLinkDialog('collage_links/embedded_pager', {
				            collage_id: collageId,
			              link_start: new_annotation_start,
			              link_end: new_annotation_end}
			            );
                }
             },
             'Cancel': function(){
                jQuery(this).dialog('close');
             }
           }
        });
        jQuery('input[name=annotation_start]').val(new_annotation_start);
		    jQuery('input[name=annotation_end]').val(new_annotation_end);
		    jQuery('input[name=collage_id]').val(collageId);
		    jQuery("#annotation_or_collage_link").dialog("open");
        jQuery("#tooltip").fadeOut();
        new_annotation_start = '';
        new_annotation_end = '';
      } else {
        var pos = el.position();
        jQuery("#tooltip").css({ left: pos.left - 100 + el.width()/2, top: pos.top + 100 }).fadeIn();
        new_annotation_start = el.attr('id');
      }
    }
  },

  observeWords: function(){
    // This is a significant burden in that it binds to every "word node" on the page, so running it must
    // align with the rights a user has to this collage, otherwise we're just wasting cpu cycles. Also
    // the controller enforces privs - so feel free to fiddle with the DOM, it won't get you anywhere.
    // jQuery('tt:visible') as a query is much less efficient - unfortunately.
    //Note: http://api.jquery.com/visible-selector/

    if(access_results.can_edit_annotations) {
      jQuery('tt').unbind('mouseover mouseout click').bind('mouseover mouseout click', jQuery.wordEvent);
      jQuery('.annotation-content').css('display', 'none');
      jQuery('.annotation-asterisk, .control-divider').unbind('click').click(function(e) {
        e.preventDefault();
        jQuery.annotationButton(jQuery(this).data('id'));
      });
    }
  },

  unObserveWords: function() {
    jQuery('tt').unbind('mouseover mouseout click');
    jQuery('.annotation-asterisk').unbind('click').click(function(e) {  
      e.preventDefault();
      jQuery.toggleAnnotation(jQuery(this).data('id'));
      jQuery.hideShowAnnotationOptions();
    });
  },

  openAnnotationDialog: function(url_path, data){
	  jQuery.ajax({
        type: 'GET',
        url: jQuery.rootPath() + url_path,
        data: data, 
        cache: false,
        beforeSend: function(){
          jQuery.showGlobalSpinnerNode();
          jQuery('div.ajax-error').html('').hide();
        },
        success: function(html){
          jQuery.hideGlobalSpinnerNode();
          jQuery('#annotation-form').html(html);
		      jQuery('#annotation-form').dialog({
		        buttons: {
              'Ok': function(){
                var values = new Array();
                  jQuery(".layer_check input").each(function(i, el) {
  	                if(jQuery(el).attr('checked')) {
  	                  values.push(jQuery(el).data('value'));
  	                }
                  });
                  jQuery('#annotation_layer_list').val(jQuery('#new_layers input').val() + ',' + values.join(','));
                  jQuery.submitAnnotation();
              },
              'Cancel': function(){
                jQuery('#new-annotation-error').html('').hide();
                jQuery(this).dialog('close');
              }
            }
          });
          jQuery('#annotation-form').dialog('open');
          jQuery("#annotation_annotation").markItUp(h2oTextileSettings);
            jQuery('#annotation_layer_list').keypress(function(e){
              if(e.keyCode == '13'){
                e.preventDefault();
                jQuery.submitAnnotation();
              }
            });
        },
        error: function(xhr){
          jQuery.hideGlobalSpinnerNode();
          jQuery('div.ajax-error').show().append(xhr.responseText);
        }
      });
  }, //end anntotation dialog

  initPlaylistItemAddButton: function(){
    jQuery('.add-Collage-button').button().click(function(e){
      e.preventDefault();
  	  var link_start = jQuery('input[name=link_start]').val();
  	  var link_end = jQuery('input[name=link_end]').val();
  	  var host_collage = jQuery('input[name=host_collage]').val();
      var itemId = jQuery(this).attr('id').split('-')[1];
  		jQuery.submitCollageLink(itemId, link_start, link_end, host_collage);
    });
  },

  initKeywordSearch: function(){
    jQuery('.Collage-button').button().click(function(e){
      e.preventDefault();
      jQuery.ajax({
        method: 'GET',
        url: jQuery.rootPath() + 'collages/embedded_pager',
        beforeSend: function(){
       		jQuery.showGlobalSpinnerNode();
        },
        data: {
            keywords: jQuery('#Collage-keyword-search').val()
        },
        dataType: 'html',
        success: function(html){
       	  jQuery.hideGlobalSpinnerNode();
          jQuery('.h2o-playlistable-Collage').html(html);
          jQuery.initPlaylistItemAddButton();
          jQuery.initKeywordSearch();
          jQuery.initPlaylistItemPagination();
        },
			  error: function(xhr){
	        jQuery.hideGlobalSpinnerNode();
	        jQuery('#new-annotation-error').show().append(xhr.responseText);
	      }
      });
    });
  },
  
  initPlaylistItemPagination: function(){
    jQuery('.h2o-playlistable-Collage .pagination a').click(
    function(e){
      e.preventDefault();
      jQuery.ajax({
        type: 'GET',
        dataType: 'html',
        beforeSend: function(){
     			jQuery.showGlobalSpinnerNode();
        },
        data: {
          keywords: jQuery('#Collage-keyword-search').val()
        },
        url: jQuery(this).attr('href'),
        success: function(html){
     			jQuery.hideGlobalSpinnerNode();
          jQuery('.h2o-playlistable-Collage').html(html);
          jQuery.initPlaylistItemAddButton();
          jQuery.initKeywordSearch();
          jQuery.initPlaylistItemPagination();
        }
      });
    });
  },

  submitCollageLink: function(linked_collage, link_start, link_end, host_collage){
	  jQuery.ajax({
      type: 'POST',
      cache: false,
      data: {collage_link: {
		    linked_collage_id: linked_collage,
		    host_collage_id: host_collage,
		    link_text_start: link_start,
    		link_text_end: link_end
        }
      },
      url: jQuery.rootPath() + 'collage_links/create',
      success: function(results){
  	    jQuery.hideGlobalSpinnerNode();
        jQuery('#annotation-form').dialog('close');
        document.location.reload(true);    
      }
    });
  },

  openCollageLinkDialog: function(url_path, data){
  	jQuery.ajax({
  	  type: 'GET',
      url: jQuery.rootPath() + url_path,
      cache: false,
      beforeSend: function(){
     		jQuery.showGlobalSpinnerNode();
      },
      data: data,
      dataType: 'html',
      success: function(html){
	      jQuery.hideGlobalSpinnerNode();
        jQuery('#annotation-form').html(html);
        jQuery('#annotation-form').dialog({
				autoOpen: false,
          width: 500,
  				minWidth: 500,
  				title: '',
  				bgiframe: true,
  				modal: true
        });
  		  jQuery.initPlaylistItemAddButton();
  		  jQuery.initKeywordSearch();
        jQuery.initPlaylistItemPagination();
  		  jQuery('#annotation-form').dialog('open');
      }
	  });
  }
});

jQuery(document).ready(function(){
  if(jQuery('.singleitem').length > 0){
    var height = jQuery('.description').height();
    if(height != 30) {
      jQuery('.toolbar,.buttons').css({ position: 'relative', top: height - 30 });
    }
    jQuery('.toolbar, .buttons').css('visibility', 'visible');

    jQuery('#cancel-annotation').click(function(e){
      e.preventDefault();
      jQuery("#tooltip").hide();
      new_annotation_start = '';
      new_annotation_end = '';
    });

    jQuery.initializeAnnotationListeners();
    jQuery.loadEditability();
    jQuery.initializeToolListeners();
    jQuery.initializeFontChange();
    jQuery.initializePrintListeners();
    jQuery.initializeLayerColorMapping();
    jQuery.initializeHeatmap();
     
    //Initializing background div for each tt
    jQuery.each(jQuery('tt'), function(i, el) {
      var node = jQuery(el);
      var position = node.position();
      var child_node = jQuery('<tt></tt>').addClass('special_highlight').css({ width: node.width(), height: node.height() });
      node.prepend(child_node);
    });
       
    jQuery('#collage-stats').click(function() {
      jQuery(this).toggleClass("active");
      if(jQuery('#collage-stats-popup').height() < 400) {
        jQuery('#collage-stats-popup').css('overflow', 'hidden');
      } else {
        jQuery('#collage-stats-popup').css('height', 400);
      }
      jQuery('#collage-stats-popup').slideToggle('fast');
      return false;
    });
    head_offset = jQuery('#fixed_header').offset();
    jQuery(window).scroll(function() {
      if(jQuery(window).scrollTop() < head_offset.top) {
        jQuery('#fixed_header').css({ position: "static", width: "auto" });
        jQuery('#collage article').css("padding-top", '13px')
        //jQuery('.special_highlight').removeClass('highlight_shift');
      } else {
        jQuery('#fixed_header').css({ position: "fixed", width: 968, top: "0px" });
        jQuery('#collage article').css("padding-top", (jQuery('#fixed_header').height() + 30) + 'px');
        //jQuery('.special_highlight').addClass('highlight_shift');
      }
    });
    jQuery('article sup a').click(function() {
      var href = jQuery(this).attr('href').replace('#', '');
      var link = jQuery('article sup a[name=' + href + ']');
      var pos = link.offset().top;
      jQuery(window).scrollTop(pos - 120);
      return false;
    });
  }
});
