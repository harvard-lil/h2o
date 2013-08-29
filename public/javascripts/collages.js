var new_annotation_start = '';
var new_annotation_end = '';
var just_hidden = 0;
var layer_info = {};
var last_annotation = 0;
var highlight_history = {};
var annotation_position = 0;
var head_offset;
var heatmap;
var clean_annotations = {};
var clean_collage_links = {};
var all_tts;
var unlayered_tts;
var update_unlayered_end = 0;

jQuery.extend({
  collage_afterload: function(results) {
    last_data = jQuery.parseJSON(results.readable_state);
    jQuery.loadState();
    if(results.can_edit_annotations) {
      jQuery.listenToRecordCollageState();
      jQuery('.requires_edit').animate({ opacity: 1.0 });
    } else {
      jQuery('.requires_edit').remove();
    }
    if(results.can_edit_description) {
      jQuery('.edit-action').animate({ opacity: 1.0 });
    } else {
      jQuery('.edit-action').remove();
    }
  },
  slideToParagraph: function() {
    if(document.location.hash.match(/^#p[0-9]+/)) {
      var p = document.location.hash.match(/[0-9]+/);
      var paragraph = jQuery('#paragraph' + p);
      var pos = paragraph.offset().top;
      jQuery(window).scrollTop(pos);
    }
  },
  observeStatsHighlights: function() {
    jQuery('#stats').hover(function() {
      jQuery(this).addClass('stats_hover');
    }, function() {
      jQuery(this).removeClass('stats_hover');
    });
  },
  updateLayerCount: function() {
    jQuery('#stats_layer_size').html(jQuery('#layers li:not(#unlayered_li)').size());
  },
  updateAnnotationCount: function() {
    var count = 0;
    jQuery.each(clean_annotations, function(i, el) {
      count++;
    });
    jQuery('#stats_annotation_size').html(count);
  },
  observeViewerToggleEdit: function() {
    jQuery('#edit_toggle').click(function(e) {
      e.preventDefault();
      jQuery('#edit_item #status_message').remove();
      var el = jQuery(this);
      if(jQuery(this).hasClass('edit_mode')) {
        jQuery('#cancel-annotation').click();
        el.removeClass('edit_mode');
        if(jQuery('#collapse_toggle').hasClass('expanded')) {
          jQuery('#edit_item').hide();
          jQuery('.singleitem').addClass('expanded_singleitem');
          jQuery.checkForPanelAdjust();
        } else {
          jQuery('#edit_item').hide();
          jQuery('#stats').show();
          jQuery.resetRightPanelThreshold();
          jQuery.checkForPanelAdjust();
        }
        jQuery.toggleEditMode(false);
        jQuery('#author_edits').removeClass('inactive');
        jQuery('#heatmap_toggle').removeClass('inactive');

        /* Forcing an autosave to save in READ mode */
        var data = jQuery.retrieveState();  
        last_data = data;
        jQuery.recordCollageState(JSON.stringify(data), false);
      } else {
        el.addClass('edit_mode');
        if(jQuery('#collapse_toggle').hasClass('expanded') || jQuery('#collapse_toggle').hasClass('special_hide')) {
          jQuery('#collapse_toggle').removeClass('expanded');
          jQuery('.singleitem').removeClass('expanded_singleitem');
          jQuery('#edit_item').show();
          jQuery.resetRightPanelThreshold();
        } else {
          jQuery('#stats').hide();
          jQuery('#edit_item').show();
          jQuery.resetRightPanelThreshold();
        }
        jQuery.toggleEditMode(true);
        if(jQuery('#hide_heatmap:visible').size()) {
          jQuery.removeHeatmapHighlights();
        }
        jQuery('#author_edits').addClass('inactive');
        jQuery('#heatmap_toggle').removeClass('disabled').addClass('inactive');
        jQuery.checkForPanelAdjust();
      }
    });
  },
  observeFootnoteLinks: function() {
    jQuery.each(jQuery('article a.footnote'), function(i, el) {
      jQuery(el).attr('href', unescape(jQuery(el).attr('href')));
      jQuery(el).attr('name', unescape(jQuery(el).attr('name')));
    });
    jQuery('article a.footnote').click(function() {
      var href = jQuery(this).attr('href').replace('#', '');
      var link = jQuery("article a[name='" + href + "']");
      if(link.size()) {
        var pos = link.offset().top;
        jQuery(window).scrollTop(pos - 150);
      }
      return false;
    });
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
  observeLayerColorMapping: function() {
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
      var new_layer = jQuery('<div class="new_layer"><p>Enter Layer Name <input type="text" name="new_layer_list[][layer]" /></p><p class="hex_input">Choose a Color<input type="hidden" name="new_layer_list[][hex]" /></p><a href="#" class="remove_layer">Cancel &raquo;</a></div>');
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
  removeHeatmapHighlights: function() {
    jQuery.each(heatmap.data, function(i, e) {
      jQuery('tt#' + i + '.heatmapped').css('background-color', '#FFFFFF').removeClass('heatmapped');
    });
  },
  applyHeatmapHighlights: function() {
    jQuery.each(heatmap.data, function(i, e) {
      var opacity = e / (heatmap.max+1);
      var color_combine = jQuery.xcolor.opacity('#FFFFFF', '#FE2A2A', opacity);
      var hex = color_combine.getHex();
      jQuery('tt#' + i).css('background-color', hex).addClass('heatmapped').data('collage_count', e);
    });
  },
  observeHeatmap: function() {
    jQuery('tt.heatmapped').live('mouseover', function(e) {
      var el = jQuery(this);
      el.css('position', 'relative');
      var heatmap_tip = jQuery('<a>')
        .addClass('heatmap_tip')
        .attr('title', 'Layered in ' + el.data('collage_count') + ' Collage(s)')
        .tipsy({ trigger: 'manual', gravity: 's', opacity: 1.0 });
      el.prepend(heatmap_tip);
      heatmap_tip.tipsy("show");
    }).live('mouseout', function(e) {
      var el = jQuery(this);
      el.css('position', 'static');
      el.find('a.heatmap_tip').tipsy("hide");
      el.find('a.heatmap_tip').remove();
    });
    jQuery('#heatmap_toggle:not(.inactive,.disabled)').live('click', function(e) {
      e.preventDefault();
      if(heatmap === undefined) {
        jQuery.ajax({
          type: 'GET',
          cache: false,
          dataType: 'JSON',
          url: jQuery.rootPath() + 'collages/' + jQuery.getItemId() + '/heatmap',
          beforeSend: function(){
            jQuery.showGlobalSpinnerNode();
          },
          success: function(data){
            jQuery('.popup .highlighted').click();
            heatmap = data.heatmap;
            jQuery.applyHeatmapHighlights();
            jQuery('#heatmap_toggle').addClass('disabled');
            jQuery.hideGlobalSpinnerNode();
          },
          error: function() {
            jQuery.hideGlobalSpinnerNode();
          }
        });
      } else {
        jQuery('.popup .highlighted').click();
        jQuery.applyHeatmapHighlights();
        jQuery('#heatmap_toggle').addClass('disabled');
        jQuery.hideGlobalSpinnerNode();
      }
    });
    jQuery('#heatmap_toggle.disabled').live('click', function(e) {
      e.preventDefault();
      if(jQuery(this).hasClass('inactive')) {
        return false;
      }
      jQuery.removeHeatmapHighlights();
      jQuery('#heatmap_toggle').removeClass('disabled');
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
  observeToolListeners: function () {
    jQuery("#collage #buttons a.btn-a:not(.btn-a-active)").live('click', function() {
      if(jQuery(this).siblings('.btn-a-active').size()) {
        var sibling = jQuery(this).siblings('.btn-a-active');
        sibling.click();
      }
      var top_pos = jQuery(this).position().top + jQuery(this).height() + 10;
      var left_pos = jQuery(this).position().left;
      jQuery(this).next('.popup').css({ top: top_pos, left: left_pos }).show();
      jQuery(this).addClass("btn-a-active");
      return false;
    });
    jQuery("#collage #buttons a.btn-a-active").live('click', function() {
      jQuery(this).next('.popup').hide();
      jQuery(this).removeClass("btn-a-active");
      return false;
    });
    jQuery('#layers li').each(function(i, el) {
      layer_info[jQuery(el).data('id')] = {
        'hex' : jQuery(el).data('hex'),
        'name' : jQuery(el).data('name')
      };
      jQuery('span.annotation-control-' + jQuery(el).data('id')).css('background', '#' + jQuery(el).data('hex'));
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
      jQuery('.unlayered-ellipsis:visible,.annotation-ellipsis:visible').click();
      jQuery('#layers a.hide_show').html('HIDE');
      jQuery('#layers a.shown').removeClass('shown');
      jQuery.hideShowUnlayeredOptions();
      jQuery.hideGlobalSpinnerNode();
    });

    jQuery('#show_unlayered').click(function(e) {
      e.preventDefault();
      jQuery.showGlobalSpinnerNode();
      jQuery('.unlayered-ellipsis:visible').click();
      jQuery('#collage article').removeClass('hide_unlayered').addClass('show_unlayered');
      jQuery.hideShowUnlayeredOptions();
      jQuery.hideGlobalSpinnerNode();
    });
    jQuery('#hide_unlayered').click(function(e) {
      e.preventDefault();
      jQuery.showGlobalSpinnerNode();
      jQuery('#collage article').removeClass('show_unlayered').addClass('hide_unlayered');
      jQuery('#collage article .unlayered-control-start').click();
      if(jQuery('.unlayered-control-end.unlayered-control-1').size()) {
        jQuery('.unlayered-control-end.unlayered-control-1').click();
      }
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

    jQuery('#layers .hide_show').live('click', function(e) {
      e.preventDefault();
      jQuery.showGlobalSpinnerNode();

      var el = jQuery(this);
      var layer_id = el.parent().data('id');
      if(el.html() == 'SHOW') {
        el.html('HIDE');
        jQuery('.annotation-ellipsis-' + layer_id).click();
      } else {
        el.html('SHOW');
        jQuery('.layered-control-start.layered-control-' + layer_id).click();
      }
      jQuery.hideGlobalSpinnerNode();
    });

    jQuery('#layers .link-o').live('click', function(e) {
      e.preventDefault();
      var el = jQuery(this);
      var id = el.parent().data('id');
      if(jQuery('#hide_heatmap').is(':visible')) {
        jQuery('#hide_heatmap').click();
      }
      if(el.hasClass('highlighted')) {
        el.siblings('.hide_show').html('HIDE');
        jQuery('article .' + id + ',.ann-annotation-' + id).css('display', 'inline-block');
        jQuery('article tt.' + id).css('display', 'inline');
        jQuery('.annotation-ellipsis-' + id).css('display', 'none');
        var hex = '#' + layer_info[id].hex;
        jQuery.each(jQuery('tt.' + id), function(i, el) {
          var current = jQuery(el);
          var highlight_colors = current.data('highlight_colors');
          highlight_colors.splice(jQuery.inArray(hex, highlight_colors), 1);
          var current_hex = '#FFFFFF';
          var opacity = 0.4 / highlight_colors.length;
          jQuery.each(highlight_colors, function(i, color) {
            var color_combine = jQuery.xcolor.opacity(current_hex, color, opacity);
            current_hex = color_combine.getHex();
          });
          if(current_hex == '#FFFFFF') {
            current.attr('style', 'display:inline;');
          } else {
            current.css('background', current_hex);
          }
          current.data('highlight_colors', highlight_colors);
        });
        el.removeClass('highlighted').html('HIGHLIGHT');
      } else {
        el.siblings('.hide_show').html('HIDE');
        jQuery('article .' + id + ',.ann-annotation-' + id).css('display', 'inline-block');
        jQuery('article tt.' + id).css('display', 'inline');
        jQuery('.annotation-ellipsis-' + id).css('display', 'none');

        var hex = '#' + layer_info[id].hex;
        jQuery.each(jQuery('tt.' + id), function(i, c) {
          var current = jQuery(c);
          var highlight_colors = current.data('highlight_colors');
          if(highlight_colors) {
            highlight_colors.push(hex);
          } else {
            highlight_colors = new Array(hex);
          }
          var current_hex = '#FFFFFF';
          var opacity = 0.4 / highlight_colors.length;
          jQuery.each(highlight_colors, function(i, color) {
            var color_combine = jQuery.xcolor.opacity(current_hex, color, opacity);
            current_hex = color_combine.getHex();
          });
          current.css('background', current_hex);
          current.data('highlight_colors', highlight_colors);
        });
        el.addClass('highlighted').html('UNHIGHLIGHT');
      }
    });
  },
  observePrintListeners: function() {
    jQuery('#fixed_print,#quickbar_print').click(function(e) {
      e.preventDefault();
      jQuery('#collage_print').submit();
    });
    jQuery('form#collage_print').submit(function() {
      var data = jQuery.retrieveState();
  
      data.highlights = {};
      jQuery.each(jQuery('.link-o.highlighted'), function(i, el) {
        data.highlights[jQuery(el).parent().data('id')] = jQuery(el).parent().data('hex');
      });

      //Note: is:visible not working here
      if(jQuery('a#hide_heatmap').css('display') == 'block' && !jQuery('a#hide_heatmap:first').is('.inactive')) {
        data.load_heatmap = true;
      }

      data.font_size = jQuery('#fontsize a.active').data('value');
      data.font_face = jQuery('#fontface a.active').data('value');
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
          jQuery('#autosave').html('Updated at: ' + results.time);
          jQuery.updateWordCount();
        }
      }
    });
  },
  updateWordCount: function() {
    var layered = all_tts.size() - unlayered_tts.size();
    jQuery('#word_stats').html(layered + ' layered, ' + unlayered_tts.size() + ' unlayered');
  },
  retrieveState: function() {
    var data = {};
    jQuery('.unlayered-ellipsis:visible').each(function(i, el) {
      data['#' + jQuery(el).attr('id')] = jQuery(el).css('display');  
    });
    jQuery('.annotation-ellipsis:visible').each(function(i, el) {
      data['#' + jQuery(el).attr('id')] = jQuery(el).css('display');  
    });
    jQuery('span.annotation-content:visible').each(function(i, el) {
      data['#' + jQuery(el).attr('id')] = jQuery(el).css('display');  
    });
    return data;
  },
  listenToRecordCollageState: function() {
    setInterval(function(i) {
      var data = jQuery.retrieveState();
      if(jQuery('#edit_toggle').hasClass('edit_mode') && (JSON.stringify(data) != JSON.stringify(last_data))) {
        last_data = data;
        jQuery.recordCollageState(JSON.stringify(data), true);
      }
    }, 1000); 
  },
  loadState: function() {
    jQuery.each(last_data, function(i, e) {
      if(i.match(/#unlayered-ellipsis/)) {
        var id = i.replace(/#unlayered-ellipsis-/, '');
        jQuery('.unlayered-control-' + id + ':first').click();
      } else if(i.match(/#annotation-ellipsis/) && e != 'none') {
        jQuery(i).css('display', 'inline');
        var annotation_id = i.replace(/#annotation-ellipsis-/, '');
        var subset = jQuery('tt.a' + annotation_id);
        subset.css('display', 'none');
        jQuery.resetParentDisplay(subset);
      } else if(i.match(/^\.a/)) { //Backwards compatibility update
        jQuery(i).css('display', 'inline');
        var annotation_id = i.replace(/^\.a/, '');
        jQuery('#annotation-ellipsis-' + annotation_id).hide();
      } else {
        jQuery(i).css('display', e);
      }
    });
    jQuery.observeWords();
    if(access_results.can_edit_annotations) {
      jQuery('#edit_toggle').click();
      jQuery.toggleEditMode(true);
      jQuery('.default-hidden').css('color', '#000');
      jQuery('#heatmap_toggle').addClass('inactive');
    } else {
      jQuery('#heatmap_toggle').removeClass('inactive');
      jQuery.toggleEditMode(false);
      jQuery.checkForPanelAdjust();
    }
    if(jQuery.cookie('scroll_pos')) {
      jQuery(window).scrollTop(jQuery.cookie('scroll_pos'));
      jQuery.cookie('scroll_pos', null);
    }
    jQuery.hideShowUnlayeredOptions();
    var show_annotations = jQuery.cookie('show_annotations');
    if(show_annotations == 'true'){
      jQuery('.annotation-content').css('display', 'inline-block');
    }
    jQuery.hideShowAnnotationOptions();
  }, 

  editAnnotationMarkup: function(annotation, color_map) {
    var old_annotation = clean_annotations["a" + annotation.id];
   
    var els = jQuery('.a' + annotation.id);
    //Manage layers and layer toolbar
    jQuery.each(old_annotation.layers, function(i, layer) {
      // This makes the assumption that the els are not layered by the same layer from another annotation
      // ie two of the same layers do not overlap
      els.removeClass('l' + layer.id);
      jQuery('.layered-control-' + annotation.id).removeClass('layered-control-l' + layer.id);
      jQuery('#annotation-ellipsis-' + annotation.id).removeClass('annotation-ellipsis-l' + layer.id);
      jQuery('.annotation-control-' + annotation.id).removeClass('annotation-control-l' + layer.id);
      jQuery('#annotation-asterisk-' + annotation.id).removeClass('l' + layer.id);
      if(jQuery('tt.l' + layer.id).not(els).length == 0) {
        jQuery("#layers li[data-id='l" + layer.id + "']").remove();
        delete layer_info['l' + layer.id];
      }
    });
    jQuery.each(annotation.layers, function(i, layer) {
      els.addClass('l' + layer.id);
      jQuery('.layered-control-' + annotation.id).addClass('layered-control-l' + layer.id);
      jQuery('#annotation-ellipsis-' + annotation.id).addClass('annotation-ellipsis-l' + layer.id);
      jQuery('.annotation-control-' + annotation.id).addClass('annotation-control-l' + layer.id);
      jQuery('#annotation-asterisk-' + annotation.id).addClass('l' + layer.id);
      if(!jQuery("#layers li[data-id='l" + layer.id + "']").length) {
        layer.hex = color_map[layer.id];
        var new_node = jQuery(jQuery.mustache(layer_tools_template, layer));
        new_node.insertBefore(jQuery('#unlayered_li'));
        layer_info['l' + layer.id] = {
          'hex' : color_map[layer.id],
          'name' : layer.name
        };
      }
    });

    //Rehighlight elements
    jQuery.each(els, function(i, c) {
      var current = jQuery(c);
      var highlight_colors = new Array();
      jQuery.each(jQuery('#layers li'), function(i, el) {
        if(jQuery(el).find('a.highlighted').size() && current.hasClass(jQuery(el).data('id'))) {
          highlight_colors.push(layer_color_map[jQuery(el).data('id')]);
        }
      });
      if(highlight_colors.length > 0) {
        var current_hex = '#FFFFFF';
        var opacity = 0.4 / highlight_colors.length;
        jQuery.each(highlight_colors, function(i, color) {
          var color_combine = jQuery.xcolor.opacity(current_hex, color, opacity);
          current_hex = color_combine.getHex();
        });
        current.css('background', current_hex);
        current.data('highlight_colors', highlight_colors);
      } else {
        current.attr('style', 'display:inline;');
      }
    });

    jQuery('#layers li').each(function(i, el) {
      jQuery.each(annotation.layers, function(j, layer) {
        if(jQuery(el).data('id') == 'l' + layer.id) {
          jQuery('.annotation-control-' + annotation.id).css('background', '#' + color_map[layer.id]);
        }
      });
    });

    //Annotation change. Use cases:
    //a) If text change only (change text only)
    //b) If text exists now but didn't before (add markup)
    //c) If text removed now but existed before (remove markup)
    //d) If no text before and no text after (do nothing)
    if(old_annotation.annotation != "" && annotation.annotation != "") {
      jQuery('span#annotation-content-' + annotation.id).html(annotation.annotation);
    } else if(old_annotation.annotation == "" && annotation.annotation != "") {
      var data = {
        "layers": annotation.layers,
        "annotation_id": annotation.id,
        "annotation_content": annotation.annotation
      };
      jQuery(jQuery.mustache(annotation_template, data)).insertAfter(jQuery('.annotation-control-' + annotation.id).last());
    } else if(old_annotation.annotation != "" && annotation.annotation == "") {
      jQuery('#annotation-content-' + annotation.id + ',#annotation-asterisk-' + annotation.id).remove();
    }
    
    //Replace in data
    clean_annotations["a" + annotation.id] = annotation;
  },
  deleteAnnotationMarkup: function(annotation) {
    //Handle class, layer assignment
    var els = jQuery('.a' + annotation.id);
    els.removeClass('a' + annotation.id);
    jQuery.each(els, function(i, el) {
      var p = jQuery(el);
      if(!(/a[0-9]/).test(p.attr('class'))) {
        p.removeClass('a');
      }
    });
    jQuery.each(annotation.layers, function(i, layer) {
      els.removeClass('l' + layer.id);
      var hex = layer_info['l' + layer.id].hex;
      jQuery.each(els, function(i, el) {
        var current = jQuery(el);
        var highlight_colors = current.data('highlight_colors');
        if(highlight_colors) {
          highlight_colors.splice(jQuery.inArray(hex, highlight_colors), 1);
        } else {
          highlight_colors = new Array();
        }
        var opacity = 0.4 / highlight_colors.length;
        var current_hex = '#FFFFFF';
        jQuery.each(highlight_colors, function(i, color) {
          var color_combine = jQuery.xcolor.opacity(current_hex, color, opacity);
          current_hex = color_combine.getHex();
        });
        if(current_hex == '#FFFFFF') {
          current.attr('style', 'display:inline;');
        } else {
          current.css('background', current_hex);
        }
        current.data('highlight_colors', highlight_colors);
      });
      if(jQuery('tt.l' + layer.id).not(els).length == 0) {
        jQuery("#layers li[data-id='l" + layer.id + "']").remove();
        delete layer_info['l' + layer.id];
      }
    });
    jQuery.updateLayerCount();

    //Remove annotation markup
    jQuery('.annotation-control-' + annotation.id + ',.layered-control-' + annotation.id).remove();
    jQuery('#annotation-ellipsis-' + annotation.id + ',#annotation-asterisk-' + annotation.id).remove();
    jQuery('#annotation-content-' + annotation.id).remove();

    //Handle Unlayered Controls
    var annotation_start = parseInt(annotation.annotation_start.replace(/^t/, ''));
    var annotation_end = parseInt(annotation.annotation_end.replace(/^t/, ''));
    jQuery.removeUnlayeredControls(els);
    if(!jQuery('tt#t' + annotation_start).hasClass('a')) {
      jQuery('tt#t' + annotation_start).removeClass('border_annotation_start');
    }
    if(!jQuery('tt#t' + annotation_end).hasClass('a')) {
      jQuery('tt#t' + annotation_end).removeClass('border_annotation_end');
    }
    for(var i = annotation_start + 1; i <= annotation_end; i++) {
      if(jQuery('tt#t' + i).hasClass('a') && !jQuery('tt#t' + (i - 1)).hasClass('a')) {
        jQuery('tt#t' + i).addClass('border_annotation_start');
      }
      if(!jQuery('tt#t' + i).hasClass('a') && jQuery('tt#t' + (i - 1)).hasClass('a')) {
        jQuery('tt#t' + (i - 1)).addClass('border_annotation_end');
      }
    }
    jQuery.addUnlayeredControls(els);

    //Delete from data
    delete annotations["a" + annotation.id];
    delete clean_annotations["a" + annotation.id];
    jQuery.updateAnnotationCount();

    unlayered_tts = jQuery('#collage article tt:not(.a)');
  },
  markupAnnotation: function(annotation, layer_color_map, page_load) {
    var annotation_start = parseInt(annotation.annotation_start.replace(/^t/, ''));
    var annotation_end = parseInt(annotation.annotation_end.replace(/^t/, ''));
    var els = all_tts.slice(annotation_start - 1, annotation_end);

    //Handle class, layer assignment
    els.addClass('a a' + annotation.id);
    jQuery.each(annotation.layers, function(i, layer) {
      els.addClass('l' + layer.id);
      if(!jQuery("#layers li[data-id='l" + layer.id + "']").size()) {
        layer.hex = layer_color_map[layer.id];
        var new_node = jQuery(jQuery.mustache(layer_tools_template, layer));
        new_node.insertBefore(jQuery('#unlayered_li'));
        layer_info['l' + layer.id] = {
          'hex' : layer_color_map[layer.id],
          'name' : layer.name
        };
      } else if(jQuery("#layers li[data-id='l" + layer.id + "'] .link-o").hasClass('highlighted')) {
        var hex = layer_color_map[layer.id];
        jQuery.each(els, function(i, c) {
          var current = jQuery(c);
          var highlight_colors = current.data('highlight_colors');
          if(highlight_colors) {
            highlight_colors.push(hex);
          } else {
            highlight_colors = new Array(hex);
          }
          var current_hex = '#FFFFFF';
          var opacity = 0.4 / highlight_colors.length;
          jQuery.each(highlight_colors, function(i, color) {
            var color_combine = jQuery.xcolor.opacity(current_hex, color, opacity);
            current_hex = color_combine.getHex();
          });
          current.css('background', current_hex);
          current.data('highlight_colors', highlight_colors);
        });
      }
    });
    jQuery.updateLayerCount();

    //Add markup
    var data = {
      annotation_id: annotation.id,
      layers: annotation.layers,
      annotation_content: annotation.annotation,
      show_annotation: (annotation.annotation == '' ? false : true)
    };

    if(jQuery('tt#t' + annotation_start).parent().hasClass('footnote')) {
      jQuery(jQuery.mustache(annotation_start_template, data)).insertBefore(jQuery('tt#t' + annotation_start).parent()); 
    } else {
      jQuery(jQuery.mustache(annotation_start_template, data)).insertBefore(jQuery('tt#t' + annotation_start)); 
    }
    jQuery(jQuery.mustache(annotation_end_template, data)).insertAfter(jQuery('tt#t' + annotation_end));

    //Important: to allow for HTML in annotation markup
    jQuery('#annotation-content-' + annotation.id).html(annotation.annotation);

    //Handle Unlayered Controls
    update_unlayered_end = 0;
    jQuery.removeUnlayeredControls(els);
    els.removeClass('border_annotation_start border_annotation_end');
    if(!jQuery('tt#t' + (annotation_start - 1)).hasClass('a')) {
      jQuery('tt#t' + annotation_start).addClass('border_annotation_start');
    }
    if(!jQuery('tt#t' + (annotation_end + 1)).hasClass('a')) {
      jQuery('tt#t' + annotation_end).addClass('border_annotation_end');
    }
    //Weird edge case where layers are highlighted next to eachother
    if(jQuery('.unlayered-control-start.unlayered-control-' + annotation_start).size()) {
      jQuery('.unlayered-control-start.unlayered-control-' + annotation_start).remove();
      jQuery('#unlayered-ellipsis-' + annotation_start).remove();
      if(jQuery('.unlayered-control-end.unlayered-control-' + annotation_start).size()) {
        var el = jQuery('.unlayered-control-end.unlayered-control-' + annotation_start);
        var renumber_tt_id = el.data('position') - 1;
        var renumber_last_annotation = all_tts.slice(0, renumber_tt_id).filter('.a:last');
        var new_unlayered_end_id = renumber_last_annotation.data('id') + 1;
        el
          .removeClass('unlayered-control-' + annotation_start)
          .addClass('unlayered-control-' + new_unlayered_end_id)
          .data('id', new_unlayered_end_id);
      }
    }
    //Another edge case
    if(update_unlayered_end != 0 && els.last().is('.border_annotation_end')) {
      var next_id = els.last().data('id') + 1;
      jQuery('.unlayered-control-' + update_unlayered_end)
        .removeClass('unlayered-control-' + update_unlayered_end)
        .addClass('unlayered-control-' + next_id)
        .data('id', next_id);
    }

    if(jQuery('.unlayered-position-' + annotation_end).size()) {
      jQuery('.unlayered-position-' + annotation_end).remove();
    }
    jQuery.addUnlayeredControls(els);

    //Display highlight and dividers
    jQuery.each(annotation.layers, function(i, layer) {
      jQuery('span.annotation-control-l' + layer.id).css('background', '#' + layer_color_map[layer.id]);
    });

    //Append to data
    clean_annotations["a" + annotation.id] = annotation;

    if(!page_load) {
      unlayered_tts = jQuery('#collage article tt:not(.a)');
      jQuery('#annotation-content-' + annotation.id).css('display', 'inline-block');
    }
    jQuery.updateAnnotationCount();
  },
  removeUnlayeredControls: function(els) {
    jQuery(els.filter('.border_annotation_start')).each(function(i, el) {
      var previous_id = jQuery(el).data('id') - 1;
      var previous_tt = jQuery('tt#t' + previous_id);
      jQuery('.unlayered-control-end.unlayered-position-' + previous_id).remove();
    }); 
    jQuery(els.filter('.border_annotation_end')).each(function(i, el) {
      var next_id = jQuery(el).data('id') + 1;
      var next_tt = jQuery('tt#t' + next_id);
      jQuery('.unlayered-control-start.unlayered-control-' + next_id).remove();
      jQuery('#unlayered-ellipsis-' + next_id).remove();
      update_unlayered_end = next_id;
    });
  },
  addUnlayeredControls: function(els) {
    jQuery(els.filter('.border_annotation_start')).each(function(i, el) {
      var previous_id = jQuery(el).data('id') - 1;
      var previous_tt = jQuery('tt#t' + previous_id);
      if(previous_tt.size() && !previous_tt.hasClass('a') && !previous_tt.next().is('.unlayered-control-end')) {
        var slice_pos = previous_tt.data('id');
        var last_annotation = all_tts.slice(0, slice_pos).filter('.a:last');
        var unlayered_end_id = 1;
        if(last_annotation.size()) {
          unlayered_end_id = last_annotation.data('id') + 1;
        }
        var data = { "unlayered_end_id" : unlayered_end_id, "position" : previous_id };
        if(previous_tt.parent().hasClass('footnote') && previous_tt.parent().parent().is('sup')) {
          jQuery(jQuery.mustache(unlayered_end_template, data)).insertAfter(previous_tt.parent().parent());
        } else if(previous_tt.parent().hasClass('footnote')) {
          jQuery(jQuery.mustache(unlayered_end_template, data)).insertAfter(previous_tt.parent());
        } else {
          jQuery(jQuery.mustache(unlayered_end_template, data)).insertAfter(previous_tt);
        }
        if(jQuery('.unlayered-control-end.unlayered-control-' + unlayered_end_id).size() == 2) {
          var last = jQuery('.unlayered-control-end.unlayered-control-' + unlayered_end_id + ':last');
          var renumber_tt_id = last.data('position') - 1;
          var renumber_last_annotation = all_tts.slice(0, renumber_tt_id).filter('.a:last');
          var new_unlayered_end_id = renumber_last_annotation.data('id') + 1;
          last
            .removeClass('unlayered-control-' + unlayered_end_id)
            .addClass('unlayered-control-' + new_unlayered_end_id)
            .data('id', new_unlayered_end_id);
        }
      }
      if(previous_id == 0 && jQuery('.unlayered-control-end.unlayered-control-1').size()) {
        var next_id = els.filter('.border_annotation_end').data('id') + 1;
        jQuery('.unlayered-control-end.unlayered-control-1').removeClass('unlayered-control-1').addClass('unlayered-control-' + next_id).data('id', next_id);
      }
    });
    jQuery(els.filter('.border_annotation_end')).each(function(i, el) {
      var next_id = jQuery(el).data('id') + 1;
      var next_tt = jQuery('tt#t' + next_id);
      if(!next_tt.hasClass('a') && !next_tt.prev().is('.unlayered-ellipsis')) {
        var data = { "unlayered_start_id" : next_id };
        if(next_tt.parent().hasClass('footnote') && next_tt.parent().parent().is('sup')) {
          jQuery(jQuery.mustache(unlayered_start_template, data)).insertBefore(next_tt.parent().parent());
        } else if(next_tt.parent().hasClass('footnote')) {
          jQuery(jQuery.mustache(unlayered_start_template, data)).insertBefore(next_tt.parent());
        } else {
          jQuery(jQuery.mustache(unlayered_start_template, data)).insertBefore(next_tt);
        }
      }
    });
  },
  markupCollageLink: function(collage_link) {
    var nodes = new Array();
    var previous_element = jQuery('tt#' + collage_link.link_text_start).prev();
    var current_node = jQuery('tt#' + collage_link.link_text_start);
    var link_node = jQuery('<a href="/collages/' + collage_link.linked_collage_id + '"></a>');
    var i = 0;
    //all_tts.size() is used to prevent infinite loop here
    while(current_node.attr('id') != collage_link.link_text_end && i < all_tts.size()) {
      nodes.push(current_node);
      current_node = current_node.next();
      i++;
    }
    nodes.push(current_node); //Last element
    jQuery.each(nodes, function(i, el) {
      el.detach;
      link_node.append(el);
    });
    link_node.insertAfter(previous_element);

    clean_collage_links["c" + collage_link.id] = collage_link;
  },
  resetParentDisplay: function(els) {
    var parents = els.parentsUntil('#collage article');
    parents.removeClass('no_visible_children');
    parents.filter(':not(:has(.layered-control,.control-divider,.unlayered-ellipsis:visible,tt:visible))').addClass('no_visible_children');
  },
  submitAnnotation: function(){
    var values = new Array();
    jQuery(".layer_check input").each(function(i, el) {
      if(jQuery(el).attr('checked')) {
        values.push(jQuery(el).data('value'));
      }
    });
    jQuery('#annotation_layer_list').val(jQuery('#new_layers input').val() + ',' + values.join(','));

    jQuery('form.annotation').ajaxSubmit({
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
        var annotation = jQuery.parseJSON(response.annotation);
        var color_map = jQuery.parseJSON(response.color_map);
        jQuery('#edit_item div.dynamic').html('').hide();
        if(response.type == "update") {
          jQuery.editAnnotationMarkup(annotation.annotation, color_map);
        } else {
          jQuery.markupAnnotation(annotation.annotation, color_map, false);
        }
        jQuery('#edit_item').append(jQuery('<div>').attr('id', 'status_message').html('Collage Edited'));
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
          jQuery('#edit_item #status_message').remove();
          jQuery.hideGlobalSpinnerNode();
          jQuery('#annotation_edit .dynamic').css('padding', '2px 0px 0px 0px').html(html).show();

          if(access_results.can_edit_annotations) {
            jQuery('#edit_item #annotation_edit .tabs a').show();
          }
        }
      });
    } else {
      jQuery('#annotation-details-' + annotationId).dialog('open');
    }
  },
  observeSelectors: function() {
    all_tts = jQuery('#collage article tt');
    var data = { "unlayered_start_id" : 1, "unlayered_end_id" : 1 };
  },
  observeStatsListener: function() {
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
  },
  observeAnnotationListeners: function(){
    jQuery('.unlayered-ellipsis').live('click', function(e) {
      e.preventDefault();
      var id = jQuery(this).data('id');

      var subset;
      if(jQuery('.unlayered-control-' + id).size() == 2) {
        subset = all_tts.slice((id - 1), jQuery('.unlayered-control-' + id + ':last').data('position'));
      } else if(id == 1) {
        subset = all_tts.slice(0, jQuery('.unlayered-control-1').data('position'));
      } else {
        subset = all_tts.slice(id - 1);
      }
      subset.css('display', 'inline');

      jQuery('.unlayered-control-' + id).css('display', 'inline-block');
      jQuery(this).css('display', 'none');
      jQuery.resetParentDisplay(subset);
      jQuery.hideShowUnlayeredOptions();
    });
    jQuery('.annotation-ellipsis').live('click', function(e) {
      e.preventDefault();
      var id = jQuery(this).data('id');
      jQuery('#annotation-control-' + id + ',#annotation-asterisk-' + id).css('display', 'inline-block');
      jQuery('article tt.a' + id).css('display', 'inline').addClass('grey');
      jQuery(this).css('display', 'none');
      jQuery('.layered-control-' + id).css('display', 'inline-block');
      jQuery.resetParentDisplay(jQuery('#collage article tt.a' + id));
    });
    jQuery('.unlayered-control').live('click', function(e) {
      e.preventDefault();
      var current = jQuery(this);
      var id = current.data('id');

      var subset;
      if(jQuery('.unlayered-control-' + id).size() == 2) {
        subset = all_tts.slice((id - 1), jQuery('.unlayered-control-' + id + ':last').data('position'));
      } else if(id == 1) {
        subset = all_tts.slice(0, current.data('position'));
      } else {
        subset = all_tts.slice(id - 1);
      }
      subset.css('display', 'none');

      jQuery('.unlayered-control-' + id).css('display', 'none');
      jQuery('#unlayered-ellipsis-' + id).css('display', 'inline-block');
      jQuery.resetParentDisplay(subset);
      jQuery.hideShowUnlayeredOptions();
    });
    jQuery('.layered-control').live('click', function(e) {
      e.preventDefault();
      var id = jQuery(this).data('id');
      jQuery('tt.a' + id + ',.layered-control-' + id).css('display', 'none');
      jQuery('#annotation-ellipsis-' + id).css('display', 'inline-block');
      jQuery.resetParentDisplay(jQuery('tt.a' + id));
    });
  },
  toggleEditMode: function(highlight) {
    if(highlight) {
      jQuery('#collage article').addClass('edit_mode');
    } else {
      jQuery('#collage article').removeClass('edit_mode');
    }
  },
  observeWords: function(){
    jQuery('tt').click(function(e) {
      if(jQuery('#edit_toggle').length && jQuery('#edit_toggle').hasClass('edit_mode')) {
        e.preventDefault();
        var el = jQuery(this);
        annotation_position = jQuery(window).scrollTop();
        if(new_annotation_start != '') {
          new_annotation_end = el.attr('id');

          if(jQuery('tt#' + new_annotation_start).data('id') > jQuery('tt#' + new_annotation_end).data('id')) {
            var tmp = new_annotation_start;
            new_annotation_start = new_annotation_end;
            new_annotation_end = tmp;
          }

          /* Important calculation to not allow overlapping collage links */
          var pos_start = jQuery('tt#' + new_annotation_start).data('id');
          var pos_end = jQuery('tt#' + new_annotation_end).data('id');
          var els = all_tts.slice(pos_start - 1, pos_end);
          var linking = false;
          var text = '';
          jQuery.each(els, function(i, el) {
            var current = jQuery(el);
            //text += current.html();
            if(current.parent().is('a')) {
              linking = true;
            }
          });
          var collageId = jQuery.getItemId();
          text += '...';

          jQuery.openAnnotationForm('annotations/new', {
            collage_id: collageId,
            annotation_start: new_annotation_start,
            annotation_end: new_annotation_end,
            text: text
          });
          if(linking) {
            jQuery('#abstract_type_annotation').click();
            jQuery('#collage_linking').show();
            jQuery('#collage_non_linking').hide(); 
            jQuery('#linking_error').show();
            jQuery('#link_edit #search_wrapper_outer').hide();
            jQuery('#link_edit .dynamic').hide().html('');
          } else {
            jQuery('#linking_error').hide();
            jQuery('#link_edit #search_wrapper_outer').show();
            jQuery('#collage_linking').hide(); 
            jQuery('#collage_non_linking').show();
            jQuery.openCollageLinkForm('collage_links/embedded_pager', {
              host_collage: collageId,
              link_start: new_annotation_start,
              link_end: new_annotation_end,
              text: text
            });
          }

          var el = jQuery('#' + jQuery('#cancel-annotation').data('id'));
          el.find('a.annotation_tip').tipsy("hide");
          el.find('a.annotation_tip').remove();
          new_annotation_start = '';
          new_annotation_end = '';
        } else {
          var el = jQuery(this);
          el.css('position', 'relative');
          var annotation_tip = jQuery('<a>')
            .addClass('annotation_tip')
            .tipsy({ trigger: 'manual', gravity: 's', opacity: 1.0, html: true, fallback: 'Your edit will start here. Please click another word to set the end point. <a href="#" data-id="' + el.attr('id') + '" id="cancel-annotation">cancel</a>' });
          el.prepend(annotation_tip);
          annotation_tip.tipsy("show");
          new_annotation_start = el.attr('id');
        }
      }
    });
    //if(jQuery('#edit-show').length && jQuery('#edit-show').html() == 'READ') {
    //if(access_results.can_edit_annotations) {
      //jQuery('.annotation-content').css('display', 'none');
    //}
  },
  observeAnnotationEditListeners: function() {
    jQuery('#edit_item .tabs a:not(.current)').live('click', function(e) {
      e.preventDefault();
      var tabs_table = jQuery(this).parentsUntil('table').parent().first();
      tabs_table.find('.current').removeClass('current');
      jQuery(this).addClass('current');
      tabs_table.siblings('.tab_panel').hide();
      jQuery('#edit_item div.' + jQuery(this).attr('id')).show();
    });
    jQuery('#edit_item .tabs a.current').live('click', function(e) {
      e.preventDefault();
    });
    jQuery('#annotation_submit').live('click', function(e) {
      e.preventDefault();
      jQuery.submitAnnotation();
    });
    jQuery('#cancel_new_annotation').live('click', function() {
      jQuery('#edit_item .dynamic').hide().html('');
      jQuery('#link_edit #search_wrapper_outer').hide();
    });
    jQuery('#delete_annotation').live('click', function(e) {
      e.preventDefault();
      var annotationId = jQuery(this).data('id');
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
          },
          success: function(response){
            jQuery.deleteAnnotationMarkup(clean_annotations["a" + annotationId]);
            jQuery('#edit_item #annotation_edit .dynamic').hide().html('');
            jQuery('#edit_item').append(jQuery('<div>').attr('id', 'status_message').html('Annotation Deleted'));
            jQuery.hideGlobalSpinnerNode();
          }
        });
      }
    });
    jQuery('#edit_annotation').live('click', function(e) {
      e.preventDefault();
      jQuery.ajax({
        type: 'GET',
        cache: false,
        url: jQuery.rootPath() + 'annotations/edit/' + jQuery(this).data('id'),
        beforeSend: function(){
          jQuery.showGlobalSpinnerNode();
          //jQuery('#new-annotation-error').html('').hide();
        },
        error: function(xhr){
          jQuery.hideGlobalSpinnerNode();
          //jQuery('#new-annotation-error').show().append(xhr.responseText);
        },
        success: function(html){
          jQuery.hideGlobalSpinnerNode();
          jQuery('<div>').attr('id', 'annotation_edit').html(html).appendTo(jQuery('#edit_item'));
          var filtered = jQuery('#annotation_annotation').val().replace(/&quot;/g, '"');
          jQuery('#annotation_annotation').val(filtered);
          jQuery("#annotation_annotation").markItUp(h2oTextileSettings);
        }
      });
    });

    jQuery('.control-divider').live('click', function(e) {
      e.preventDefault();
      if(jQuery('#edit_toggle').length && jQuery('#edit_toggle').hasClass('edit_mode')) {
        jQuery.annotationButton(jQuery(this).data('id'));
      }
    });
    jQuery('.annotation-asterisk').live('click', function(e) {
      e.preventDefault();
      var annotation_id = jQuery(this).data('id');
      jQuery.toggleAnnotation(annotation_id);
      jQuery.hideShowAnnotationOptions();
      if(jQuery('#edit_toggle').length && jQuery('#edit_toggle').hasClass('edit_mode')) {
        if(!jQuery('#delete_annotation').length || jQuery('#delete_annotation').data('id') != annotation_id) {
          jQuery.annotationButton(annotation_id);
        }
      }
    });
  },
  openAnnotationForm: function(url_path, data){
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
          jQuery('#edit_item #status_message').remove();
          jQuery('#annotation_edit .dynamic').css('padding', '10px').html(html).show();
          //jQuery('<div>').attr('id', 'annotation_edit').addClass('tab_panel new_annotation').html(html).appendTo(jQuery('#edit_item'));
        },
        error: function(xhr){
          jQuery.hideGlobalSpinnerNode();
          jQuery('div.ajax-error').show().append(xhr.responseText);
        }
      });
  }, //end anntotation dialog

  initPlaylistItemAddButton: function(){
    jQuery('.add-collage-button').live('click', function(e) {
      e.preventDefault();
      var link_start = jQuery('input[name=link_start]').val();
      var link_end = jQuery('input[name=link_end]').val();
      var host_collage = jQuery('input[name=host_collage]').val();
      var itemId = jQuery(this).attr('id').split('-')[1];
      jQuery.submitCollageLink(itemId, link_start, link_end, host_collage);
    });
  },

  initKeywordSearch: function(){
    jQuery('#link_search').live('click', function(e) {
      e.preventDefault();
      jQuery.ajax({
        method: 'GET',
        url: jQuery.rootPath() + 'collage_links/embedded_pager',
        beforeSend: function(){
           jQuery.showGlobalSpinnerNode();
        },
        data: {
            keywords: jQuery('#collage-keyword-search').val(),
            link_start: jQuery('#edit_item input[name=link_start]').val(),
            link_end: jQuery('#edit_item input[name=link_end]').val(),
            host_collage: jQuery('#edit_item input[name=host_collage]').val(),
            text: jQuery('#edit_item input[name=text]').val()
        },
        dataType: 'html',
        success: function(html){
          jQuery.hideGlobalSpinnerNode();
          jQuery('#link_edit .dynamic').html(html);
        },
        error: function(xhr){
          jQuery.hideGlobalSpinnerNode();
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
        jQuery('#link_edit .dynamic,#annotation_edit .dynamic').hide().html('');
        jQuery('#link_edit #search_wrapper_outer').hide();
        jQuery('#edit_item').append(jQuery('<div>').attr('id', 'status_message').html('Link Created'));
        jQuery.markupCollageLink(results.collage_link);
      }
    });
  },

  openCollageLinkForm: function(url_path, data){
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
        jQuery('#link_edit .dynamic').html(html).show();
      }
    });
  }
});

jQuery(document).ready(function(){
  if(jQuery('.singleitem').length > 0){
    jQuery.showGlobalSpinnerNode();
    jQuery.observeSelectors();

    jQuery('.toolbar, #buttons').css('visibility', 'visible');
    jQuery('#cancel-annotation').live('click', function(e){
      e.preventDefault();
      var el = jQuery('#' + jQuery(this).data('id'));
      el.find('a.annotation_tip').tipsy("hide");
      el.find('a.annotation_tip').remove();
      new_annotation_start = '';
      new_annotation_end = '';
    });

    jQuery.each(annotations, function(i, el) {
      clean_annotations[i] = jQuery.parseJSON(el).annotation;
      jQuery.markupAnnotation(clean_annotations[i], layer_color_map, true);
    });

    unlayered_tts = jQuery('#collage article tt:not(.a)');
    if(!jQuery('tt#t1').is('.a')) {
      jQuery('<a class="unlayered-ellipsis" id="unlayered-ellipsis-1" data-id="1" href="#">[...]</a>').insertBefore(jQuery('tt#t1'));
    }

    jQuery.each(collage_links, function(i, el) {
      clean_collage_links[i] = el.collage_link;
      jQuery.markupCollageLink(clean_collage_links[i]);
    });

    jQuery.observeAnnotationListeners();
    jQuery.observeToolListeners();
    jQuery.observePrintListeners();
    jQuery.observeLayerColorMapping();
    jQuery.observeHeatmap();
    jQuery.observeAnnotationEditListeners();
  
    jQuery.observeStatsListener();

    /* Collage Search */
    jQuery.initKeywordSearch();
    jQuery.initPlaylistItemAddButton();

    jQuery.observeFootnoteLinks();
    jQuery.hideGlobalSpinnerNode();
    jQuery.observeViewerToggleEdit();
    jQuery.observeStatsHighlights();
          
    jQuery.updateWordCount();

    jQuery.slideToParagraph();

    //Must be after onclicks initiated
    if(jQuery.cookie('user_id') == null) {
      access_results = { 'can_edit_annotations' : false };
      last_data = original_data;
      jQuery.loadState();
    }
  }
});

var annotation_start_template = '\
<span class="control-divider annotation-control-{{annotation_id}}{{#layers}} annotation-control-l{{id}}{{/layers}}" data-id="{{annotation_id}}" href="#"></span>\
<span class="layered-control layered-control-start layered-control-{{annotation_id}}{{#layers}} layered-control-l{{id}}{{/layers}}" data-id="{{annotation_id}}" href="#"></span>\
<span class="annotation-ellipsis annotation-ellipsis{{#layers}} annotation-ellipsis-l{{id}}{{/layers}}" id="annotation-ellipsis-{{annotation_id}}" data-id="{{annotation_id}}">[...]</span>';

var annotation_end_template = '\
<span class="layered-control layered-control-end layered-control-{{annotation_id}}{{#layers}} layered-control-l{{id}}{{/layers}}" href="#" data-id="{{annotation_id}}"></span>\
<span class="arr control-divider annotation-control-{{annotation_id}}{{#layers}} annotation-control-l{{id}}{{/layers}}" href="#" data-id="{{annotation_id}}"></span>\
{{#show_annotation}}\
<span class="annotation-content" id="annotation-content-{{annotation_id}}">{{annotation_content}}</span>\
<span class="annotation-asterisk{{#layers}} l{{id}}{{/layers}}" id="annotation-asterisk-{{annotation_id}}" data-id="{{annotation_id}}"></span>\
{{/show_annotation}}';

var annotation_template = '\
<span class="annotation-content" id="annotation-content-{{annotation_id}}">{{annotation_content}}</span>\
<span class="annotation-asterisk{{#layers}} l{{id}}{{/layers}}" id="annotation-asterisk-{{annotation_id}}" data-id="{{annotation_id}}"></span>';

var unlayered_start_template = '\
<span class="unlayered-control unlayered-control-start unlayered-control-{{unlayered_start_id}}" data-id="{{unlayered_start_id}}" href="#"></span>\
<span class="unlayered-ellipsis" id="unlayered-ellipsis-{{unlayered_start_id}}" data-id="{{unlayered_start_id}}" href="#" style="display:none;">[...]</span>';

var unlayered_end_template = '\
<span class="unlayered-control unlayered-control-end unlayered-control-{{unlayered_end_id}} unlayered-position-{{position}}" data-position="{{position}}" data-id="{{unlayered_end_id}}" href="#"></span>';

var layer_tools_template = '\
<li data-hex="{{hex}}" data-name="{{name}}" data-id="l{{id}}">\
<strong>{{name}}</strong>\
<a class="hide_show shown tooltip" href="#" original-title="Hide the {{name}} layer">HIDE</a>\
<a class="tooltip link-o" href="#" original-title="Highlight the {{name}} Layer" style="background: #{{hex}};">HIGHLIGHT</a>\
<div class="cl">&nbsp;</div>\
</li>';
