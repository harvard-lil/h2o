var new_annotation_start = '';
var new_annotation_end = '';
var just_hidden = 0;
var layer_info = {};
var last_annotation = 0;
var highlight_history = {};
var annotation_position = 0;
var head_offset;

jQuery.extend({
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
      if(jQuery(this).hasClass("btn-a-active")) {
        jQuery('.font-size-popup .jsb-moreButton').click();
      }
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
      if(el.hasClass('highlighted')) {
        el.siblings('.hide_show').find('strong').html('HIDE');
        jQuery('article .' + id + ',.ann-annotation-' + id).css('display', 'inline-block');
        jQuery('article tt.' + id).css('display', 'inline');
        jQuery('.annotation-ellipsis-' + id).css('display', 'none');
        jQuery('.annotation-ellipsis-' + id).each (function(i, el) {
          jQuery.highlightHistoryRemove(id, jQuery(el).data('id'), false);
        });
        el.removeClass('highlighted').html('HIGHLIGHT');
      } else {
        el.siblings('.hide_show').find('strong').html('HIDE');
        jQuery('article .' + id + ',.ann-annotation-' + id).css('display', 'inline-block');
        jQuery('article tt.' + id).css('display', 'inline');
        jQuery('.annotation-ellipsis-' + id).css('display', 'none');
        jQuery('.annotation-ellipsis-' + id).each (function(i, el) {
          jQuery.highlightHistoryAdd(id, jQuery(el).data('id'), false);
        });
        el.addClass('highlighted').html('UNHIGHLIGHT');
      }
    });
  
    jQuery("#edit-show").click(function(e) {
      e.preventDefault();
      var el = jQuery(this);
      if(el.html() == "READ") {
        el.html("EDIT"); 
        jQuery.unObserveWords();
        jQuery('.details .edit-action, .control-divider').css('display', 'none');
        jQuery('article tt.a').removeClass('edit_highlight');
        jQuery('.default-hidden,article tt.grey').css('color', '#666');
        jQuery('.layered-control,.unlayered-control').width(9).height(16);
        jQuery('#author_edits').removeClass('inactive');

        /* Forcing an autosave to save in READ mode */
        var data = jQuery.retrieveState();  
        last_data = data;
        jQuery.recordCollageState(JSON.stringify(data), false);
      } else {
        el.html("READ");  
        jQuery.observeWords();
        jQuery('#author_edits').addClass('inactive');
        jQuery('.details .edit-action').show();
        jQuery('.control-divider').css('display', 'inline-block');
        jQuery('article tt.a').addClass('edit_highlight');
        jQuery('.default-hidden,article tt.grey').css('color', '#000');
        jQuery('.layered-control,.unlayered-control').width(0).height(0);
      }
      el.toggleClass('editing');
    });
  },
  initializePrintListeners: function() {
    jQuery('#print-container form').submit(function() {
      var data = jQuery.retrieveState();
      data.highlights = {};
      jQuery.each(highlight_history, function(i, v) {
        data.highlights['.a' + i] = v[v.length - 1];
      });

      jQuery('#state').val(JSON.stringify(data));
    });
  },
  highlightHistoryAdd: function(id, aid, highlighted) {
    if(!highlight_history[aid]) {
      highlight_history[aid] = ['ffffff'];
    }

    if(highlighted) {
      highlight_history[aid].push(layer_info[id].hex);
    } else {
      var update = [];
      jQuery.each(highlight_history[aid], function(i, v) {
        if(layer_info[id].hex != v) {
          update.push(v);
        }
      });
      update.push(layer_info[id].hex);
      highlight_history[aid] = update;
    }
    var last = highlight_history[aid].length - 1;
    jQuery('tt.a' + aid).css('background', '#' + highlight_history[aid][last]);
  },
  highlightHistoryRemove: function(id, aid, highlighted) {
    if(highlighted) {
      highlight_history[aid].pop();
    } else {
      var update = [];
      jQuery.each(highlight_history[aid], function(i, v) {
        if(layer_info[id].hex != v) {
          update.push(v);
        }
      });
      highlight_history[aid] = update;
    }
    var last = highlight_history[aid].length - 1;
    jQuery('tt.a' + aid).css('background', '#' + highlight_history[aid][last]);
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
    if(last_data.edit_mode && is_owner) {
      jQuery('#edit-show').html("READ");  
       jQuery.observeWords();
      jQuery('.details .edit-action').show();
      jQuery('.control-divider').css('display', 'inline-block');
      jQuery('article tt.a').addClass('edit_highlight');
      jQuery('.default-hidden').css('color', '#000');
      jQuery('.layered-control,.unlayered-control').width(0).height(0);
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
                          jQuery('#annotation_layer_list').val(jQuery('#new_layers input').val() + ',' + values.join(','));
                          jQuery.submitAnnotation();
                        },
                        Cancel: function(){
                          jQuery('#new-annotation-error').html('').hide();
                          jQuery(this).dialog('close');
                        }
                      }
                    });
                    jQuery("#annotation_annotation").markItUp(h2oTextileSettings);

                    jQuery('#annotation_layer_list').keypress(function(e){
                      if(e.keyCode == '13'){
                        e.preventDefault();
                        jQuery.submitAnnotation();
                      }
                    });
                  }
                });
              }
            }
          });

          jQuery('#annotation-tabs-' + annotationId).tabs();
          if(!is_owner) {
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
        jQuery('#annotation-form').dialog({
          bgiframe: true,
          autoOpen: false,
          minWidth: 450,
          width: 450,
          modal: true,
          title: 'New Annotation',
          buttons: {
            'Save': function(){
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
        jQuery.ajax({
          type: 'GET',
          url: jQuery.rootPath() + 'annotations/new',
          data: {
            collage_id: collageId,
            annotation_start: new_annotation_start,
            annotation_end: new_annotation_end
          },
          cache: false,
          beforeSend: function(){
            jQuery.showGlobalSpinnerNode();
            jQuery('div.ajax-error').html('').hide();
          },
          success: function(html){
            jQuery.hideGlobalSpinnerNode();
            jQuery('#annotation-form').html(html);
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

    if(is_owner) {
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
      } else {
        jQuery('#fixed_header').css({ position: "fixed", width: 968, top: "0px" });
        jQuery('#collage article').css("padding-top", (jQuery('#fixed_header').height() + 30) + 'px');
      }
    });
  }
});
