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

h2o_global.collage_afterload = function(results) {
  last_data = original_data;
  collages.loadState();
  if(results.can_edit_annotations) {
    collages.listenToRecordCollageState();
    $('.requires_edit').animate({ opacity: 1.0 });
  } else {
    $('.requires_edit').remove();
  }
  if(results.can_edit_description) {
    $('.edit-action').animate({ opacity: 1.0 });
  } else {
    $('.edit-action').remove();
  }
  if($.cookie('user_id') == 2053) {
    $('.upgrade-action').show();
  } else {
    $('.upgrade-action').remove();
  }
};

var collages = {
  initiate_annotator: function() {
    //dummy function for annotator version 1
  },
  xPathFromSingleNode: function(node, type, root_selector) {
    var index = node.parent().find('> *').index(node);
    if(type == 'end') {
      index += 1;
    }
    var prev_items = node.parent().find('> *:lt(' + index + ')');
    var offset = 0;
    for(var j = 0; j < prev_items.size(); j++) {
      offset += $(prev_items[j]).text().length;
    }
    var path = '';
    $.each(node.parentsUntil(root_selector), function(i, el) {
      var tagName = $(el)[0].tagName;
      var idx = $(el).parent().children(tagName).index($(el)) + 1;
      idx = "[" + idx + "]";
      path = "/" + $(el)[0].tagName.toLowerCase() + idx + path;
    });
    return { "xpath" : path, "offset" : offset };
  },
  xPathFromAllAnnotations: function() {
    all_tts.show();

    //Removing spaces at the end of lines / paragraphs / etc.
    $.each($('div.article *:has(tt)'), function(i, el) {
      var last_tt = $(el).find('tt:last');
      var t = last_tt.text().replace(/ $/, '');
      last_tt.text(t);
    });

    //Removing items that should not be included in offset calculation
    $('.control-divider,.layered-control,.annotation-ellipsis,.annotation-content,.annotation-asterisk,.paragraph-numbering,.unlayered-control,.unlayered-ellipsis').remove();

    var data = { annotations: {}, collage_links: {} };
    $.each(clean_annotations, function(i, annotation) {
      var start_data = collages.xPathFromSingleNode($('tt#' + annotation.annotation_start), 'start', 'div.article');
      var end_data = collages.xPathFromSingleNode($('tt#' + annotation.annotation_end), 'end', 'div.article');
      data.annotations[annotation.id] = { "xpath_start": start_data.xpath, "xpath_end" : end_data.xpath, "start_offset" : start_data.offset, "end_offset" : end_data.offset }; 
    });
    $.each(clean_collage_links, function(i, collage_link) {
      $('tt#' + collage_link.link_text_start).unwrap();
      var start_data = collages.xPathFromSingleNode($('tt#' + collage_link.link_text_start), 'start', 'div.article');
      var end_data = collages.xPathFromSingleNode($('tt#' + collage_link.link_text_end), 'end', 'div.article');
      data.collage_links[collage_link.id] = { "xpath_start": start_data.xpath, "xpath_end" : end_data.xpath, "start_offset" : start_data.offset, "end_offset" : end_data.offset }; 
    });
    return data;
  },
  observeUpgradeCollage: function() {
    $('.upgrade-action').live('click', function(e) {
      e.preventDefault();

      var node = $('<p>').html('You have chosen to upgrade the annotator tool used by this collage.<br />This will reset the current saved collage state. This action <b>can not</b> be reverted.<br />Would you like to continue?');
      $(node).dialog({
        title: 'Upgrade Collage Annotation Tool',
        width: 'auto',
        height: 'auto',
        buttons: {
          Yes: function() {
            $.ajax({
              type: 'post',
              dataType: 'json',
              data: { "data" : collages.xPathFromAllAnnotations() },
              url: '/collages/' + h2o_global.getItemId() + '/upgrade_annotator',
              beforeSend: function() {
                h2o_global.showGlobalSpinnerNode();
              },
              success: function(data) {
                setTimeout(function() {
                  location.reload();
                }, 500);
              },
              complete: function() {
                h2o_global.hideGlobalSpinnerNode();
              }
            });
          },
          No: function() {
            $(node).dialog('close');
          }
        }
      });
    });
  },
  observeDeleteInheritedAnnotations: function () {
    $('#delete_inherited_annotations').live('click', function(e) {
      e.preventDefault();
      $.ajax({
        type: 'GET',
        cache: false,
        dataType: 'JSON',
        url: h2o_global.root_path() + 'collages/' + h2o_global.getItemId() + '/delete_inherited_annotations',
        beforeSend: function(){
          h2o_global.showGlobalSpinnerNode();
        },
        success: function(data){
          $('.unlayered-ellipsis:visible').click();
          $('div.article').removeClass('hide_unlayered').addClass('show_unlayered');
          collages.hideShowUnlayeredOptions();
          var deleted_annotations = $.parseJSON(data.deleted);
          $.each(deleted_annotations, function(i, a) {
            collages.deleteAnnotationMarkup(clean_annotations["a" + a.annotation.id]);
          });
          $('#inherited_h,#inherited_span').remove();
          $('.unlayered-control').hide();
          h2o_global.hideGlobalSpinnerNode();
        },
        error: function() {
          h2o_global.hideGlobalSpinnerNode();
        }
      });
    });
  },
  slideToParagraph: function() {
    if(document.location.hash.match(/^#p[0-9]+/)) {
      var p = document.location.hash.match(/[0-9]+/);
      var paragraph = $('#paragraph' + p);
      var pos = paragraph.offset().top;
      $(window).scrollTop(pos);
    }
  },
  observeStatsHighlights: function() {
    $('#stats').hover(function() {
      $(this).addClass('stats_hover');
    }, function() {
      $(this).removeClass('stats_hover');
    });
  },
  updateLayerCount: function() {
    $('#stats_layer_size').html($('#layers li').size());
  },
  updateAnnotationCount: function() {
    var count = 0;
    $.each(clean_annotations, function(i, el) {
      count++;
    });
    $('#stats_annotation_size').html(count);
  },
  observeViewerToggleEdit: function() {
    $('#edit_toggle,#quickbar_edit_toggle').click(function(e) {
      e.preventDefault();
      $('#edit_item #status_message').remove();
      var el = $(this);
      if($(this).hasClass('edit_mode')) {
        $('#cancel-annotation').click();
        $('#edit_toggle,#quickbar_edit_toggle').removeClass('edit_mode');
        if($('#collapse_toggle').hasClass('expanded')) {
          $('#edit_item').hide();
          $('.singleitem').addClass('expanded_singleitem');
          h2o_global.checkForPanelAdjust();
        } else {
          $('#edit_item').hide();
          $('#stats').show();
          h2o_global.resetRightPanelThreshold();
          h2o_global.checkForPanelAdjust();
        }
        collages.toggleEditMode(false);
        $('#heatmap_toggle').removeClass('inactive');

        /* Forcing an autosave to save in READ mode */
        var data = collages.retrieveState();  
        last_data = data;
        collages.recordCollageState(JSON.stringify(data), false);
      } else {
        $('#edit_toggle,#quickbar_edit_toggle').addClass('edit_mode');
        if($('#collapse_toggle').hasClass('expanded') || $('#collapse_toggle').hasClass('special_hide')) {
          $('#collapse_toggle').removeClass('expanded');
          $('.singleitem').removeClass('expanded_singleitem');
          $('#edit_item').show();
          h2o_global.resetRightPanelThreshold();
        } else {
          $('#stats').hide();
          $('#edit_item').show();
          h2o_global.resetRightPanelThreshold();
        }
        collages.toggleEditMode(true);
        if($('#hide_heatmap:visible').size()) {
          collages.removeHeatmapHighlights();
        }
        $('#heatmap_toggle').removeClass('disabled').addClass('inactive');
        h2o_global.checkForPanelAdjust();
      }
    });
  },
  observeFootnoteLinks: function() {
    $.each($('div.article a.footnote'), function(i, el) {
      $(el).attr('href', unescape($(el).attr('href')));
      $(el).attr('name', unescape($(el).attr('name')));
    });
    $('div.article a.footnote').click(function() {
      var href = $(this).attr('href').replace('#', '');
      var link = $("div.article a[name='" + href + "']");
      if(link.size()) {
        var pos = link.offset().top;
        $(window).scrollTop(pos - 150);
      }
      return false;
    });
  },
  getHexes: function() {
    var hexes = $('<div class="hexes"></div>');
    $.each(color_list, function(i, item) {
      var node = $('<a href="#"></a>').data('value', item.hex).css({ 'background' : '#' + item.hex });
      if($(".layer_check [data-value='" + item.hex + "']").length) {
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
    $('.hexes a').live('click', function() {
      if($(this).hasClass('inactive')) {
        return false;
      }
      $(this).parent().siblings('.hex_input').find('input').val($(this).data('value'));
      $(this).siblings('a.active').removeClass('active');
      $(this).addClass('active');
      return false;
    });
    $('#add_new_layer').live('click', function() {
      var new_layer = $('<div class="new_layer"><p>Enter Layer Name <input type="text" name="new_layer_list[][layer]" /></p><p class="hex_input">Choose a Color<input type="hidden" name="new_layer_list[][hex]" /></p><a href="#" class="remove_layer">Cancel &raquo;</a></div>');
      var hexes = collages.getHexes();
      hexes.insertBefore(new_layer.find('.remove_layer'));
      $('#new_layers').append(new_layer);
      return false;
    });
    $('.remove_layer').live('click', function() {
      $(this).parent().remove();
      return false;
    });
  },
  removeHeatmapHighlights: function() {
    $.each(heatmap.data, function(i, e) {
      $('tt#' + i + '.heatmapped').css('background-color', '#FFFFFF').removeClass('heatmapped');
    });
  },
  applyHeatmapHighlights: function() {
    $.each(heatmap.data, function(i, e) {
      var opacity = e / (heatmap.max+1);
      var color_combine = $.xcolor.opacity('#FFFFFF', '#FE2A2A', opacity);
      var hex = color_combine.getHex();
      $('tt#' + i).css('background-color', hex).addClass('heatmapped').data('collage_count', e);
    });
  },
  observeHeatmap: function() {
    $('tt.heatmapped').live('mouseover', function(e) {
      var el = $(this);
      el.css('position', 'relative');
      var heatmap_tip = $('<a>')
        .addClass('heatmap_tip')
        .attr('title', 'Layered in ' + el.data('collage_count') + ' Collage(s)')
        .tipsy({ trigger: 'manual', gravity: 's', opacity: 1.0 });
      el.prepend(heatmap_tip);
      heatmap_tip.tipsy("show");
    }).live('mouseout', function(e) {
      var el = $(this);
      el.css('position', 'static');
      el.find('a.heatmap_tip').tipsy("hide");
      el.find('a.heatmap_tip').remove();
    });
    $('#heatmap_toggle:not(.inactive,.disabled)').live('click', function(e) {
      e.preventDefault();
      if(heatmap === undefined) {
        $.ajax({
          type: 'GET',
          cache: false,
          dataType: 'JSON',
          url: h2o_global.root_path() + 'collages/' + h2o_global.getItemId() + '/heatmap',
          beforeSend: function(){
            h2o_global.showGlobalSpinnerNode();
          },
          success: function(data){
            $('.popup .highlighted').click();
            heatmap = data.heatmap;
            collages.applyHeatmapHighlights();
            $('#heatmap_toggle').addClass('disabled');
            h2o_global.hideGlobalSpinnerNode();
          },
          error: function() {
            h2o_global.hideGlobalSpinnerNode();
          }
        });
      } else {
        $('.popup .highlighted').click();
        collages.applyHeatmapHighlights();
        $('#heatmap_toggle').addClass('disabled');
        h2o_global.hideGlobalSpinnerNode();
      }
    });
    $('#heatmap_toggle.disabled').live('click', function(e) {
      e.preventDefault();
      if($(this).hasClass('inactive')) {
        return false;
      }
      collages.removeHeatmapHighlights();
      $('#heatmap_toggle').removeClass('disabled');
    });
  },
  hideShowAnnotationOptions: function(check_user_preferences) {
    var total = $('span.annotation-content').size();
    var shown = $('span.annotation-content').filter(':visible').size();

    //Check user cookie for showing annotations
    if(total != shown && check_user_preferences) {
      if($.cookie('show_annotations') == 'true' && $.cookie('user_id') != $('#author-link').data('author_id')) {
        $('.annotation-content').css('display', 'inline-block');
      }
      total = shown;
    }

    $('#show_annotations,#hide_annotations,#annotations_na').hide();
    if(total == 0 && shown == 0) {
      $('#annotations_na').show();
    } else if(total == shown) {
      $('#hide_annotations').show();
    } else if(shown == 0) {
      $('#show_annotations').show();
    } else {
      $('#show_annotations,#hide_annotations').show();
    }
  },
  hideShowUnlayeredOptions: function() {
    var total = $('.unlayered-ellipsis').size();
    var shown = $('.unlayered-ellipsis').filter(':visible').size();
    if(total == shown) {
      $('#hide_unlayered').hide();
      $('#show_unlayered').show();
    } else if(shown == 0) {
      $('#hide_unlayered').show();
      $('#show_unlayered').hide();
    } else {
      $('#show_unlayered,#hide_unlayered').show();
    } 
  },
  observeToolListeners: function () {
    $("#buttons a.btn-a:not(.btn-a-active)").live('click', function(e) {
      e.preventDefault();
      var top_pos = $(this).position().top + $(this).height() + 10;
      var left_pos = $(this).width() - 208;
      $('.text-layers-popup').css({ position: 'absolute', top: top_pos, left: left_pos, "z-index": 1 }).fadeIn(200);
      $(this).addClass("btn-a-active");
    });
    $("#buttons a.btn-a-active").live('click', function(e) {
      e.preventDefault();
      $('.text-layers-popup').fadeOut(200);
      $(this).removeClass("btn-a-active");
    });
    $('#quickbar_tools:not(.active)').live('click', function(e) {
      e.preventDefault();
      var top_pos = $(this).position().top + $(this).height() + 8;
      var left_pos = $(this).position().left - 198 + $(this).width();
      $('.text-layers-popup').css({ position: 'fixed', top: top_pos, left: left_pos, "z-index": 5 }).fadeIn(200);
      $(this).addClass('active');
    });
    $('#quickbar_tools.active').live('click', function(e) {
      e.preventDefault();
      $('.text-layers-popup').fadeOut(200);
      $(this).removeClass('active');
    });
    $('#layers li').each(function(i, el) {
      layer_info[$(el).data('id')] = {
        'hex' : $(el).data('hex'),
        'name' : $(el).data('name')
      };
      $('span.annotation-control-' + $(el).data('id')).css('background', '#' + $(el).data('hex'));
    });
    $('#author_edits').click(function(e) {
      e.preventDefault();
      last_data = original_data;
      collages.loadState();
    });
    $('#full_text').click(function(e) {
      e.preventDefault();
      var el = $(this);
      h2o_global.showGlobalSpinnerNode();
      $('.unlayered-ellipsis:visible,.annotation-ellipsis:visible').click();

      $.each($('#layers a.hide_show'), function(i, el) {
        $(el).html('HIDE "' + $(el).parent().data('name') + '"');
      });

      $('#layers a.shown').removeClass('shown');
      collages.hideShowUnlayeredOptions();
      h2o_global.hideGlobalSpinnerNode();
    });

    $('#show_unlayered a').click(function(e) {
      e.preventDefault();
      h2o_global.showGlobalSpinnerNode();
      $('.unlayered-ellipsis:visible').click();
      $('div.article').removeClass('hide_unlayered').addClass('show_unlayered');
      collages.hideShowUnlayeredOptions();
      h2o_global.hideGlobalSpinnerNode();
    });
    $('#hide_unlayered a').click(function(e) {
      e.preventDefault();
      h2o_global.showGlobalSpinnerNode();
      $('div.article').removeClass('show_unlayered').addClass('hide_unlayered');
      $('div.article .unlayered-control-start').click();
      if($('.unlayered-control-end.unlayered-control-1').size()) {
        $('.unlayered-control-end.unlayered-control-1').click();
      }
      collages.hideShowUnlayeredOptions();
      h2o_global.hideGlobalSpinnerNode();
    });

    $('#show_annotations a').not('.inactive').click(function(e) {
      e.preventDefault();
      h2o_global.showGlobalSpinnerNode();
      $('.annotation-content').css('display', 'inline-block');
      h2o_global.hideGlobalSpinnerNode();
      collages.hideShowAnnotationOptions(false);
    });
    $('#hide_annotations a').not('.inactive').click(function(e) {
      e.preventDefault();
      h2o_global.showGlobalSpinnerNode();
      $('.annotation-content').css('display', 'none');
      h2o_global.hideGlobalSpinnerNode();
      collages.hideShowAnnotationOptions(false);
    });

    $('#layers .hide_show').live('click', function(e) {
      e.preventDefault();
      h2o_global.showGlobalSpinnerNode();

      var el = $(this);
      var layer_id = el.parent().data('id');
      var layer_name = el.parent().data('name');
      if(el.html().match("SHOW ")) {
        el.html('HIDE "' + layer_name + '"');
        $('.annotation-ellipsis-' + layer_id).click();
      } else {
        el.html('SHOW "' + layer_name + '"');
        $('.layered-control-start.layered-control-' + layer_id).click();
      }
      h2o_global.hideGlobalSpinnerNode();
    });

    $('#layers_highlights .link-o').live('click', function(e) {
      e.preventDefault();
      var el = $(this);
      var id = el.parent().data('id');
      var layer_name = el.parent().data('name');
      var indicator_hex = $(this).find('.indicator').css('background-color');

      if($('#hide_heatmap').is(':visible')) {
        $('#hide_heatmap').click();
      }

      if($('#layers a.' + id).html().match("SHOW")) {
        $('#layers a.' + id).click();
      }
      if(el.hasClass('highlighted')) {

        $('div.article .' + id + ',.ann-annotation-' + id).css('display', 'inline-block');
        $('div.article tt.' + id).css('display', 'inline');
        $('.annotation-ellipsis-' + id).css('display', 'none');
        var hex = '#' + layer_info[id].hex;
        $.each($('tt.' + id), function(i, el) {
          var current = $(el);
          var highlight_colors = current.data('highlight_colors');
          highlight_colors.splice($.inArray(hex, highlight_colors), 1);
          var current_hex = '#FFFFFF';
          var opacity = 0.4 / highlight_colors.length;
          $.each(highlight_colors, function(i, color) {
            var color_combine = $.xcolor.opacity(current_hex, color, opacity);
            current_hex = color_combine.getHex();
          });
          if(current_hex == '#FFFFFF') {
            current.attr('style', 'display:inline;');
          } else {
            current.css('background', current_hex);
          }
          current.data('highlight_colors', highlight_colors);
        });
        el.removeClass('highlighted').html('HIGHLIGHT "' + layer_name + '"<span class="indicator" style="background-color:' + indicator_hex + '"></span>');
      } else {
        $('div.article .' + id + ',.ann-annotation-' + id).css('display', 'inline-block');
        $('div.article tt.' + id).css('display', 'inline');
        $('.annotation-ellipsis-' + id).css('display', 'none');

        var hex = '#' + layer_info[id].hex;
        $.each($('tt.' + id), function(i, c) {
          var current = $(c);
          var highlight_colors = current.data('highlight_colors');
          if(highlight_colors) {
            highlight_colors.push(hex);
          } else {
            highlight_colors = new Array(hex);
          }
          var current_hex = '#FFFFFF';
          var opacity = 0.4 / highlight_colors.length;
          $.each(highlight_colors, function(i, color) {
            var color_combine = $.xcolor.opacity(current_hex, color, opacity);
            current_hex = color_combine.getHex();
          });
          current.css('background', current_hex);
          current.data('highlight_colors', highlight_colors);
        });
        el.addClass('highlighted').html('UNHIGHLIGHT "' + layer_name + '"<span class="indicator" style="background-color:' + indicator_hex + '"></span>');
      }
    });
  },
  observePrintListeners: function() {
    $('#fixed_print,#quickbar_print').click(function(e) {
      e.preventDefault();
      $('#collage_print').submit();
    });
    $('form#collage_print').submit(function() {
      var data = collages.retrieveState();
  
      //Note: is:visible not working here
      if($('a#hide_heatmap').css('display') == 'block' && !$('a#hide_heatmap:first').is('.inactive')) {
        data.load_heatmap = true;
      }

      data.font_size = $('#fontsize a.active').data('value');
      data.font_face = $('#fontface a.active').data('value');
      $('#state').val(JSON.stringify(data));
    });
  },
  recordCollageState: function(data, show_message) {
    var words_shown = $('div.article tt').filter(':visible').size();
    $.ajax({
      type: 'POST',
      cache: false,
      data: {
        readable_state: data,
        words_shown: words_shown
      },
      url: h2o_global.root_path() + 'collages/' + h2o_global.getItemId() + '/save_readable_state',
      success: function(results){
        if(show_message) {
          $('#autosave').html('Updated at: ' + results.time);
          collages.updateWordCount();
        }
      }
    });
  },
  updateWordCount: function() {
    var layered = all_tts.size() - unlayered_tts.size();
    $('#word_stats').html(layered + ' layered, ' + unlayered_tts.size() + ' unlayered');
  },
  retrieveState: function() {
    var data = {};
    $('.unlayered-ellipsis:visible').each(function(i, el) {
      data['#' + $(el).attr('id')] = $(el).css('display');  
    });
    $('.annotation-ellipsis:visible').each(function(i, el) {
      data['#' + $(el).attr('id')] = $(el).css('display');  
    });
    $('span.annotation-content:visible').each(function(i, el) {
      data['#' + $(el).attr('id')] = $(el).css('display');  
    });
      
    data.highlights = {};
    $.each($('.link-o.highlighted'), function(i, el) {
      data.highlights[$(el).parent().data('id')] = $(el).parent().data('hex');
    });

    return data;
  },
  listenToRecordCollageState: function() {
    setInterval(function(i) {
      var data = collages.retrieveState();
      if($('#edit_toggle').hasClass('edit_mode') && (JSON.stringify(data) != JSON.stringify(last_data))) {
        last_data = data;
        collages.recordCollageState(JSON.stringify(data), true);
      }
    }, 1000); 
  },
  loadState: function() {
    $.each(last_data, function(i, e) {
      if(i.match(/#unlayered-ellipsis/)) {
        var id = i.replace(/#unlayered-ellipsis-/, '');
        $('.unlayered-control-' + id + ':first').click();
      } else if(i.match(/#annotation-ellipsis/) && e != 'none') {
        $(i).css('display', 'inline');
        var annotation_id = i.replace(/#annotation-ellipsis-/, '');
        var subset = $('tt.a' + annotation_id);
        subset.css('display', 'none');
        collages.resetParentDisplay(subset);
      } else if(i.match(/^\.a/)) { //Backwards compatibility update
        $(i).css('display', 'inline');
        var annotation_id = i.replace(/^\.a/, '');
        $('#annotation-ellipsis-' + annotation_id).hide();
      } else if(i == 'highlights') {
        $.each(e, function(j, k) {
          $("ul#layers_highlights li[data-id='" + j + "'] a").click();
        });
      } else {
        $(i).css('display', e);
      }
    });
    collages.observeWords();
    if(access_results.can_edit_annotations) {
      $('#edit_toggle').click();
      collages.toggleEditMode(true);
      $('.default-hidden').css('color', '#000');
      $('#heatmap_toggle').addClass('inactive');
    } else {
      $('#heatmap_toggle').removeClass('inactive');
      collages.toggleEditMode(false);
      h2o_global.checkForPanelAdjust();
    }
    if($.cookie('scroll_pos')) {
      $(window).scrollTop($.cookie('scroll_pos'));
      $.cookie('scroll_pos', null);
    }
    collages.hideShowUnlayeredOptions();
    collages.hideShowAnnotationOptions(true);
  }, 

  editAnnotationMarkup: function(annotation, color_map) {
    var old_annotation = clean_annotations["a" + annotation.id];
   
    var els = $('.a' + annotation.id);
    //Manage layers and layer toolbar
    $.each(old_annotation.layers, function(i, layer) {
      // This makes the assumption that the els are not layered by the same layer from another annotation
      // ie two of the same layers do not overlap
      els.removeClass('l' + layer.id);
      $('.layered-control-' + annotation.id).removeClass('layered-control-l' + layer.id);
      $('#annotation-ellipsis-' + annotation.id).removeClass('annotation-ellipsis-l' + layer.id);
      $('.annotation-control-' + annotation.id).removeClass('annotation-control-l' + layer.id);
      $('#annotation-asterisk-' + annotation.id).removeClass('l' + layer.id);
      if($('tt.l' + layer.id).not(els).length == 0) {
        $("#layers li[data-id='l" + layer.id + "']").remove();
        delete layer_info['l' + layer.id];
      }
    });
    $.each(annotation.layers, function(i, layer) {
      els.addClass('l' + layer.id);
      $('.layered-control-' + annotation.id).addClass('layered-control-l' + layer.id);
      $('#annotation-ellipsis-' + annotation.id).addClass('annotation-ellipsis-l' + layer.id);
      $('.annotation-control-' + annotation.id).addClass('annotation-control-l' + layer.id);
      $('#annotation-asterisk-' + annotation.id).addClass('l' + layer.id);
      if(!$("#layers li[data-id='l" + layer.id + "']").length) {
        layer.hex = color_map[layer.id];

        var new_node = $($.mustache(layer_tools_visibility, layer));
        new_node.appendTo($('#layers'));
        var new_node2 = $($.mustache(layer_tools_highlights, layer));
        new_node2.appendTo($('#layers_highlights'));

        layer_info['l' + layer.id] = {
          'hex' : color_map[layer.id],
          'name' : layer.name
        };
      }
    });

    //Rehighlight elements
    $.each(els, function(i, c) {
      var current = $(c);
      var highlight_colors = new Array();
      $.each($('#layers li'), function(i, el) {
        if($(el).find('a.highlighted').size() && current.hasClass($(el).data('id'))) {
          highlight_colors.push(layer_color_map[$(el).data('id')]);
        }
      });
      if(highlight_colors.length > 0) {
        var current_hex = '#FFFFFF';
        var opacity = 0.4 / highlight_colors.length;
        $.each(highlight_colors, function(i, color) {
          var color_combine = $.xcolor.opacity(current_hex, color, opacity);
          current_hex = color_combine.getHex();
        });
        current.css('background', current_hex);
        current.data('highlight_colors', highlight_colors);
      } else {
        current.attr('style', 'display:inline;');
      }
    });

    $('#layers li').each(function(i, el) {
      $.each(annotation.layers, function(j, layer) {
        if($(el).data('id') == 'l' + layer.id) {
          $('.annotation-control-' + annotation.id).css('background', '#' + color_map[layer.id]);
        }
      });
    });

    //Annotation change. Use cases:
    //a) If text change only (change text only)
    //b) If text exists now but didn't before (add markup)
    //c) If text removed now but existed before (remove markup)
    //d) If no text before and no text after (do nothing)
    if(old_annotation.annotation != "" && annotation.annotation != "") {
      $('span#annotation-content-' + annotation.id).html(annotation.annotation);
    } else if(old_annotation.annotation == "" && annotation.annotation != "") {
      var data = {
        "layers": annotation.layers,
        "annotation_id": annotation.id,
        "annotation_content": annotation.annotation
      };
      $($.mustache(annotation_template, data)).insertAfter($('.annotation-control-' + annotation.id).last());
    } else if(old_annotation.annotation != "" && annotation.annotation == "") {
      $('#annotation-content-' + annotation.id + ',#annotation-asterisk-' + annotation.id).remove();
    }
    
    //Replace in data
    clean_annotations["a" + annotation.id] = annotation;
  },
  deleteAnnotationMarkup: function(annotation) {
    //Handle class, layer assignment
    var els = $('.a' + annotation.id);
    els.removeClass('a' + annotation.id);
    $.each(els, function(i, el) {
      var p = $(el);
      if(!(/a[0-9]/).test(p.attr('class'))) {
        p.removeClass('a');
      }
    });
    $.each(annotation.layers, function(i, layer) {
      els.removeClass('l' + layer.id);
      var hex = layer_info['l' + layer.id].hex;
      $.each(els, function(i, el) {
        var current = $(el);
        var highlight_colors = current.data('highlight_colors');
        if(highlight_colors) {
          highlight_colors.splice($.inArray(hex, highlight_colors), 1);
        } else {
          highlight_colors = new Array();
        }
        var opacity = 0.4 / highlight_colors.length;
        var current_hex = '#FFFFFF';
        $.each(highlight_colors, function(i, color) {
          var color_combine = $.xcolor.opacity(current_hex, color, opacity);
          current_hex = color_combine.getHex();
        });
        if(current_hex == '#FFFFFF') {
          current.attr('style', 'display:inline;');
        } else {
          current.css('background', current_hex);
        }
        current.data('highlight_colors', highlight_colors);
      });
      if($('tt.l' + layer.id).not(els).length == 0) {
        $("#layers li[data-id='l" + layer.id + "']").remove();
        $("#layers_highlights li[data-id='l" + layer.id + "']").remove();
        delete layer_info['l' + layer.id];
      }
    });
    collages.updateLayerCount();

    //Remove annotation markup
    $('.annotation-control-' + annotation.id + ',.layered-control-' + annotation.id).remove();
    $('#annotation-ellipsis-' + annotation.id + ',#annotation-asterisk-' + annotation.id).remove();
    $('#annotation-content-' + annotation.id).remove();

    //Handle Unlayered Controls
    var annotation_start = parseInt(annotation.annotation_start.replace(/^t/, ''));
    var annotation_end = parseInt(annotation.annotation_end.replace(/^t/, ''));
    collages.removeUnlayeredControls(els);
    if(!$('tt#t' + annotation_start).hasClass('a')) {
      $('tt#t' + annotation_start).removeClass('border_annotation_start');
    }
    if(!$('tt#t' + annotation_end).hasClass('a')) {
      $('tt#t' + annotation_end).removeClass('border_annotation_end');
    }
    for(var i = annotation_start + 1; i <= annotation_end + 1; i++) {
      if($('tt#t' + i).hasClass('a') && !$('tt#t' + (i - 1)).hasClass('a')) {
        $('tt#t' + i).addClass('border_annotation_start');
      }
      if(!$('tt#t' + i).hasClass('a') && $('tt#t' + (i - 1)).hasClass('a')) {
        $('tt#t' + (i - 1)).addClass('border_annotation_end');
      }
    }
    collages.addUnlayeredControls(els);

    //Edge case where annotation on first tt is deleted
    if(!$('tt#t1').is('.a') && $('#unlayered-ellipsis-1').size() == 0) {
      $('<a class="unlayered-ellipsis" id="unlayered-ellipsis-1" data-id="1" href="#">[...]</a>').css('display', 'none').insertBefore($('tt#t1'));
      if($('tt#t' + update_unlayered_end).is('.a')) {
        var data = { "unlayered_end_id" : 1, "position" : update_unlayered_end - 1 };
        $($.mustache(unlayered_end_template, data)).insertAfter($('tt#t' + (update_unlayered_end - 1)));
      } else {
        var node_to_modify = $('.unlayered-control-' + update_unlayered_end);
        node_to_modify.removeClass('.unlayered-control-' + update_unlayered_end).addClass('unlayered-control-1').data('id', 1);
        subset = all_tts.slice(0, node_to_modify.data('position'));
        subset.css('display', 'inline');
        collages.hideShowUnlayeredOptions();
      }
    }

    //Delete from data
    delete annotations["a" + annotation.id];
    delete clean_annotations["a" + annotation.id];
    collages.updateAnnotationCount();

    unlayered_tts = $('div.article tt:not(.a)');
  },
  markupAnnotation: function(annotation, layer_color_map, page_load) {
    var annotation_start = parseInt(annotation.annotation_start.replace(/^t/, ''));
    var annotation_end = parseInt(annotation.annotation_end.replace(/^t/, ''));
    var els = all_tts.slice(annotation_start - 1, annotation_end);

    //Handle class, layer assignment
    els.addClass('a a' + annotation.id);
    $.each(annotation.layers, function(i, layer) {
      els.addClass('l' + layer.id);
      if(!$("#layers li[data-id='l" + layer.id + "']").size()) {
        layer.hex = layer_color_map[layer.id];

        var new_node = $($.mustache(layer_tools_visibility, layer));
        new_node.appendTo($('#layers'));
        var new_node2 = $($.mustache(layer_tools_highlights, layer));
        new_node2.appendTo($('#layers_highlights'));

        layer_info['l' + layer.id] = {
          'hex' : layer_color_map[layer.id],
          'name' : layer.name
        };
      } else if($("#layers li[data-id='l" + layer.id + "'] .link-o").hasClass('highlighted')) {
        var hex = layer_color_map[layer.id];
        $.each(els, function(i, c) {
          var current = $(c);
          var highlight_colors = current.data('highlight_colors');
          if(highlight_colors) {
            highlight_colors.push(hex);
          } else {
            highlight_colors = new Array(hex);
          }
          var current_hex = '#FFFFFF';
          var opacity = 0.4 / highlight_colors.length;
          $.each(highlight_colors, function(i, color) {
            var color_combine = $.xcolor.opacity(current_hex, color, opacity);
            current_hex = color_combine.getHex();
          });
          current.css('background', current_hex);
          current.data('highlight_colors', highlight_colors);
        });
      }
    });
    collages.updateLayerCount();

    //Add markup
    var data = {
      annotation_id: annotation.id,
      layers: annotation.layers,
      annotation_content: annotation.annotation,
      show_annotation: (annotation.annotation == '' ? false : true)
    };

    if($('tt#t' + annotation_start).parent().hasClass('footnote')) {
      $($.mustache(annotation_start_template, data)).insertBefore($('tt#t' + annotation_start).parent()); 
    } else {
      $($.mustache(annotation_start_template, data)).insertBefore($('tt#t' + annotation_start)); 
    }
    $($.mustache(annotation_end_template, data)).insertAfter($('tt#t' + annotation_end));

    //Important: to allow for HTML in annotation markup
    $('#annotation-content-' + annotation.id).html(annotation.annotation);

    //Handle Unlayered Controls
    update_unlayered_end = 0;
    collages.removeUnlayeredControls(els);
    els.removeClass('border_annotation_start border_annotation_end');
    if(!$('tt#t' + (annotation_start - 1)).hasClass('a')) {
      $('tt#t' + annotation_start).addClass('border_annotation_start');
    }
    if(!$('tt#t' + (annotation_end + 1)).hasClass('a')) {
      $('tt#t' + annotation_end).addClass('border_annotation_end');
    }
    //Weird edge case where layers are highlighted next to eachother
    if($('.unlayered-control-start.unlayered-control-' + annotation_start).size()) {
      $('.unlayered-control-start.unlayered-control-' + annotation_start).remove();
      $('#unlayered-ellipsis-' + annotation_start).remove();
      if($('.unlayered-control-end.unlayered-control-' + annotation_start).size()) {
        var el = $('.unlayered-control-end.unlayered-control-' + annotation_start);
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
      $('.unlayered-control-' + update_unlayered_end)
        .removeClass('unlayered-control-' + update_unlayered_end)
        .addClass('unlayered-control-' + next_id)
        .data('id', next_id);
    }
    if(annotation_start == 1 && $('#unlayered-ellipsis-1').size() == 1) {
      $('#unlayered-ellipsis-1').remove();
    }

    if($('.unlayered-position-' + annotation_end).size()) {
      $('.unlayered-position-' + annotation_end).remove();
    }
    collages.addUnlayeredControls(els);

    //Display highlight and dividers
    $.each(annotation.layers, function(i, layer) {
      $('span.annotation-control-l' + layer.id).css('background', '#' + layer_color_map[layer.id]);
    });

    //Append to data
    clean_annotations["a" + annotation.id] = annotation;

    if(!page_load) {
      unlayered_tts = $('div.article tt:not(.a)');
      $('#annotation-content-' + annotation.id).css('display', 'inline-block');
    }
    collages.updateAnnotationCount();
  },
  removeUnlayeredControls: function(els) {
    var removed_border_start = 0;
    $(els.filter('.border_annotation_start')).each(function(i, el) {
      var previous_id = $(el).data('id') - 1;
      var previous_tt = $('tt#t' + previous_id);
      removed_border_start = $('.unlayered-control-end.unlayered-position-' + previous_id).data('id');
      $('.unlayered-control-end.unlayered-position-' + previous_id).remove();
    }); 
    $(els.filter('.border_annotation_end')).each(function(i, el) {
      var next_id = $(el).data('id') + 1;
      var next_tt = $('tt#t' + next_id);
      $('.unlayered-control-start.unlayered-control-' + next_id).remove();
      $('#unlayered-ellipsis-' + next_id).remove();
      update_unlayered_end = next_id;
    });
    if(removed_border_start != 0 && update_unlayered_end != 0) {
      $('.unlayered-control-' + update_unlayered_end)
        .removeClass('unlayered-control-' + update_unlayered_end)
        .addClass('unlayered-control-' + removed_border_start)
        .data('id', removed_border_start);
    }
  },
  addUnlayeredControls: function(els) {
    $(els.filter('.border_annotation_start')).each(function(i, el) {
      var previous_id = $(el).data('id') - 1;
      var previous_tt = $('tt#t' + previous_id);
      if(previous_tt.size() && !previous_tt.hasClass('a') && !previous_tt.next().is('.unlayered-control-end')) {
        var slice_pos = previous_tt.data('id');
        var last_annotation = all_tts.slice(0, slice_pos).filter('.a:last');
        var unlayered_end_id = 1;
        if(last_annotation.size()) {
          unlayered_end_id = last_annotation.data('id') + 1;
        }
        var data = { "unlayered_end_id" : unlayered_end_id, "position" : previous_id };
        if(previous_tt.parent().hasClass('footnote') && previous_tt.parent().parent().is('sup')) {
          $($.mustache(unlayered_end_template, data)).insertAfter(previous_tt.parent().parent());
        } else if(previous_tt.parent().hasClass('footnote')) {
          $($.mustache(unlayered_end_template, data)).insertAfter(previous_tt.parent());
        } else {
          $($.mustache(unlayered_end_template, data)).insertAfter(previous_tt);
        }
        if($('.unlayered-control-end.unlayered-control-' + unlayered_end_id).size() == 2) {
          var last = $('.unlayered-control-end.unlayered-control-' + unlayered_end_id + ':last');
          var renumber_tt_id = last.data('position') - 1;
          var renumber_last_annotation = all_tts.slice(0, renumber_tt_id).filter('.a:last');
          var new_unlayered_end_id = renumber_last_annotation.data('id') + 1;
          last
            .removeClass('unlayered-control-' + unlayered_end_id)
            .addClass('unlayered-control-' + new_unlayered_end_id)
            .data('id', new_unlayered_end_id);
        }
      }
      if(previous_id == 0 && $('.unlayered-control-end.unlayered-control-1').size()) {
        var next_id = els.filter('.border_annotation_end').data('id') + 1;
        $('.unlayered-control-end.unlayered-control-1').removeClass('unlayered-control-1').addClass('unlayered-control-' + next_id).data('id', next_id);
      }
    });
    $(els.filter('.border_annotation_end')).each(function(i, el) {
      var next_id = $(el).data('id') + 1;
      var next_tt = $('tt#t' + next_id);
      if(!next_tt.hasClass('a') && !next_tt.prev().is('.unlayered-ellipsis')) {
        var data = { "unlayered_start_id" : next_id };
        var new_node = $($.mustache(unlayered_start_template, data));
        if(next_tt.parent().hasClass('footnote') && next_tt.parent().parent().is('sup')) {
          new_node.insertBefore(next_tt.parent().parent());
        } else if(next_tt.parent().hasClass('footnote')) {
          new_node.insertBefore(next_tt.parent());
        } else {
          new_node.insertBefore(next_tt);
        }
      }
    });
  },
  markupCollageLink: function(collage_link) {
    var nodes = new Array();
    var previous_element = $('tt#' + collage_link.link_text_start).prev();
    var current_node = $('tt#' + collage_link.link_text_start);
    var link_node = $('<a class="collage-link" href="/collages/' + collage_link.linked_collage_id + '"></a>');
    var i = 0;
    //all_tts.size() is used to prevent infinite loop here
    while(current_node.attr('id') != collage_link.link_text_end && i < all_tts.size()) {
      nodes.push(current_node);
      current_node = current_node.next();
      i++;
    }
    nodes.push(current_node); //Last element
    $.each(nodes, function(i, el) {
      el.detach;
      link_node.append(el);
    });
    link_node.insertAfter(previous_element);

    clean_collage_links["c" + collage_link.id] = collage_link;
  },
  resetParentDisplay: function(els) {
    var parents = els.parentsUntil('div.article');
    parents.removeClass('no_visible_children');
    parents.filter(':not(:has(.layered-control,.control-divider,.unlayered-ellipsis:visible,tt:visible))').addClass('no_visible_children');
  },
  submitAnnotation: function(){
    var values = new Array();
    $(".layer_check input").each(function(i, el) {
      if($(el).attr('checked')) {
        values.push($(el).data('value'));
      }
    });
    $('#annotation_layer_list').val($('#new_layers input').val() + ',' + values.join(','));

    $('form.annotation').ajaxSubmit({
      error: function(xhr){
        h2o_global.hideGlobalSpinnerNode();
        $('#new-annotation-error').show().append(xhr.responseText);
      },
      beforeSend: function(){
        $.cookie('scroll_pos', annotation_position);
        h2o_global.showGlobalSpinnerNode();
        $('div.ajax-error').html('').hide();
        $('#new-annotation-error').html('').hide();
      },
      success: function(response){
        h2o_global.hideGlobalSpinnerNode();
        var annotation = $.parseJSON(response.annotation);
        var color_map = $.parseJSON(response.color_map);
        $('#edit_item div.dynamic').html('').hide();
        if(response.type == "update") {
          collages.editAnnotationMarkup(annotation.annotation, color_map);
        } else {
          collages.markupAnnotation(annotation.annotation, color_map, false);
        }
        collages.hideShowAnnotationOptions(false);
        $('#edit_item').append($('<div>').attr('id', 'status_message').html('Collage Edited'));
      }
    });
  },

  toggleAnnotation: function(id) {
    if($('#annotation-content-' + id).css('display') == 'inline-block') {
      $('#annotation-content-' + id).css('display', 'none');
    } else {
      $('#annotation-content-' + id).css('display', 'inline-block');
    }
  },

  annotationButton: function(annotationId){
    var collageId = h2o_global.getItemId();
    if($('#annotation-details-' + annotationId).length == 0){
      $.ajax({
        type: 'GET',
        cache: false,
        url: h2o_global.root_path() + 'annotations/' + annotationId,
        beforeSend: function(){
          h2o_global.showGlobalSpinnerNode();
          $('div.ajax-error').html('').hide();
        },
        error: function(xhr){
          h2o_global.hideGlobalSpinnerNode();
          $('div.ajax-error').show().append(xhr.responseText);
        },
        success: function(html){
          $('#edit_item #status_message').remove();
          h2o_global.hideGlobalSpinnerNode();
          $('#annotation_edit .dynamic').css('padding', '2px 0px 0px 0px').html(html).show();

          if(access_results.can_edit_annotations) {
            $('#edit_item #annotation_edit .tabs a').show();
          }
        }
      });
    } else {
      $('#annotation-details-' + annotationId).dialog('open');
    }
  },
  observeSelectors: function() {
    all_tts = $('div.article tt');
    var data = { "unlayered_start_id" : 1, "unlayered_end_id" : 1 };
  },
  observeStatsListener: function() {
    $('#collage-stats').click(function() {
      $(this).toggleClass("active");
      if($('#collage-stats-popup').height() < 400) {
        $('#collage-stats-popup').css('overflow', 'hidden');
      } else {
        $('#collage-stats-popup').css('height', 400);
      }
      $('#collage-stats-popup').slideToggle('fast');
      return false;
    });
  },
  observeAnnotationListeners: function(){
    $('.unlayered-ellipsis').live('click', function(e) {
      e.preventDefault();
      var id = $(this).data('id');

      var subset;
      if($('.unlayered-control-' + id).size() == 2) {
        subset = all_tts.slice((id - 1), $('.unlayered-control-' + id + ':last').data('position'));
      } else if(id == 1) {
        subset = all_tts.slice(0, $('.unlayered-control-1').data('position'));
      } else {
        subset = all_tts.slice(id - 1);
      }
      subset.css('display', 'inline');

      $('.unlayered-control-' + id).css('display', 'inline-block');
      $(this).css('display', 'none');
      collages.resetParentDisplay(subset);
      collages.hideShowUnlayeredOptions();
    });
    $('.annotation-ellipsis').live('click', function(e) {
      e.preventDefault();
      var id = $(this).data('id');
      $('#annotation-control-' + id + ',#annotation-asterisk-' + id).css('display', 'inline-block');
      $(this).css('display', 'none');
      $('.layered-control-' + id).css('display', 'inline-block');
      var subset = $('div.article tt.a' + id);
      subset.css('display', 'inline');
      collages.resetParentDisplay(subset);
    });
    $('.unlayered-control').live('click', function(e) {
      e.preventDefault();
      var current = $(this);
      var id = current.data('id');

      var subset;
      if($('.unlayered-control-' + id).size() == 2) {
        subset = all_tts.slice((id - 1), $('.unlayered-control-' + id + ':last').data('position'));
      } else if(id == 1) {
        subset = all_tts.slice(0, current.data('position'));
      } else {
        subset = all_tts.slice(id - 1);
      }
      subset.css('display', 'none');

      $('.unlayered-control-' + id).css('display', 'none');
      $('#unlayered-ellipsis-' + id).css('display', 'inline-block');
      collages.resetParentDisplay(subset);
      collages.hideShowUnlayeredOptions();
    });
    $('.layered-control').live('click', function(e) {
      e.preventDefault();
      var id = $(this).data('id');
      $('tt.a' + id + ',.layered-control-' + id).css('display', 'none');
      $('#annotation-ellipsis-' + id).css('display', 'inline-block');
      collages.resetParentDisplay($('tt.a' + id));
    });
  },
  toggleEditMode: function(highlight) {
    if(highlight) {
      $('div.article').addClass('edit_mode');
    } else {
      $('div.article').removeClass('edit_mode');
    }
  },
  observeWords: function(){
    $('tt').click(function(e) {
      if($('#edit_toggle').length && $('#edit_toggle').hasClass('edit_mode')) {
        e.preventDefault();
        var el = $(this);
        annotation_position = $(window).scrollTop();
        if(new_annotation_start != '') {
          new_annotation_end = el.attr('id');

          if($('tt#' + new_annotation_start).data('id') > $('tt#' + new_annotation_end).data('id')) {
            var tmp = new_annotation_start;
            new_annotation_start = new_annotation_end;
            new_annotation_end = tmp;
          }

          /* Important calculation to not allow overlapping collage links */
          var pos_start = $('tt#' + new_annotation_start).data('id');
          var pos_end = $('tt#' + new_annotation_end).data('id');
          var els = all_tts.slice(pos_start - 1, pos_end);
          var linking = false;
          var text = '';
          $.each(els, function(i, el) {
            var current = $(el);
            //text += current.html();
            if(current.parent().is('a')) {
              linking = true;
            }
          });
          var collageId = h2o_global.getItemId();
          text += '...';

          collages.openAnnotationForm('annotations/new', {
            collage_id: collageId,
            annotation_start: new_annotation_start,
            annotation_end: new_annotation_end,
            text: text
          });
          if(linking) {
            $('#abstract_type_annotation').click();
            $('#collage_linking').show();
            $('#collage_non_linking').hide(); 
            $('#linking_error').show();
            $('#link_edit #search_wrapper_outer').hide();
            $('#link_edit .dynamic').hide().html('');
          } else {
            $('#linking_error').hide();
            $('#link_edit #search_wrapper_outer').show();
            $('#collage_linking').hide(); 
            $('#collage_non_linking').show();
            collages.openCollageLinkForm('collage_links/embedded_pager', {
              host_collage: collageId,
              link_start: new_annotation_start,
              link_end: new_annotation_end,
              text: text
            });
          }

          var el = $('#' + $('#cancel-annotation').data('id'));
          el.find('a.annotation_tip').tipsy("hide");
          el.find('a.annotation_tip').remove();
          new_annotation_start = '';
          new_annotation_end = '';
        } else {
          var el = $(this);
          el.css('position', 'relative');
          var annotation_tip = $('<a>')
            .addClass('annotation_tip')
            .tipsy({ trigger: 'manual', gravity: 's', opacity: 1.0, html: true, fallback: 'Your edit will start here. Please click another word to set the end point. <a href="#" data-id="' + el.attr('id') + '" id="cancel-annotation">cancel</a>' });
          el.prepend(annotation_tip);
          annotation_tip.tipsy("show");
          new_annotation_start = el.attr('id');
        }
      }
    });
    //if($('#edit-show').length && $('#edit-show').html() == 'READ') {
    //if(access_results.can_edit_annotations) {
      //$('.annotation-content').css('display', 'none');
    //}
  },
  observeAnnotationEditListeners: function() {
    $('#edit_item .tabs a:not(.current)').live('click', function(e) {
      e.preventDefault();
      var tabs_table = $(this).parentsUntil('table').parent().first();
      tabs_table.find('.current').removeClass('current');
      $(this).addClass('current');
      tabs_table.siblings('.tab_panel').hide();
      $('#edit_item div.' + $(this).attr('id')).show();
    });
    $('#edit_item .tabs a.current').live('click', function(e) {
      e.preventDefault();
    });
    $('#annotation_submit').live('click', function(e) {
      e.preventDefault();
      collages.submitAnnotation();
    });
    $('#cancel_new_annotation').live('click', function() {
      $('#edit_item .dynamic').hide().html('');
      $('#link_edit #search_wrapper_outer').hide();
    });
    $('#delete_annotation').live('click', function(e) {
      e.preventDefault();
      var annotationId = $(this).data('id');
      if(confirm('Are you sure?')){
        $.ajax({
          cache: false,
          type: 'POST',
          data: {
            '_method': 'delete'
          },
          url: h2o_global.root_path() + 'annotations/destroy/' + annotationId,
          beforeSend: function(){
            h2o_global.showGlobalSpinnerNode();
          },
          error: function(xhr){
            h2o_global.hideGlobalSpinnerNode();
          },
          success: function(response){
            collages.deleteAnnotationMarkup(clean_annotations["a" + annotationId]);
            $('#edit_item #annotation_edit .dynamic').hide().html('');
            $('#edit_item').append($('<div>').attr('id', 'status_message').html('Annotation Deleted'));
            collages.hideShowAnnotationOptions(false);
            h2o_global.hideGlobalSpinnerNode();
          }
        });
      }
    });
    $('#edit_annotation').live('click', function(e) {
      e.preventDefault();
      $.ajax({
        type: 'GET',
        cache: false,
        url: h2o_global.root_path() + 'annotations/edit/' + $(this).data('id'),
        beforeSend: function(){
          h2o_global.showGlobalSpinnerNode();
          //$('#new-annotation-error').html('').hide();
        },
        error: function(xhr){
          h2o_global.hideGlobalSpinnerNode();
          //$('#new-annotation-error').show().append(xhr.responseText);
        },
        success: function(html){
          h2o_global.hideGlobalSpinnerNode();
          $('<div>').attr('id', 'annotation_edit').html(html).appendTo($('#edit_item'));
          var filtered = $('#annotation_annotation').val().replace(/&quot;/g, '"');
          $('#annotation_annotation').val(filtered);
          $("#annotation_annotation").markItUp(h2oTextileSettings);
        }
      });
    });

    $('.control-divider').live('click', function(e) {
      e.preventDefault();
      if($('#edit_toggle').length && $('#edit_toggle').hasClass('edit_mode')) {
        collages.annotationButton($(this).data('id'));
      }
    });
    $('.annotation-asterisk').live('click', function(e) {
      e.preventDefault();
      var annotation_id = $(this).data('id');
      collages.toggleAnnotation(annotation_id);
      collages.hideShowAnnotationOptions(false);
      if($('#edit_toggle').length && $('#edit_toggle').hasClass('edit_mode')) {
        if(!$('#delete_annotation').length || $('#delete_annotation').data('id') != annotation_id) {
          collages.annotationButton(annotation_id);
        }
      }
    });
  },
  openAnnotationForm: function(url_path, data){
    $.ajax({
        type: 'GET',
        url: h2o_global.root_path() + url_path,
        data: data, 
        cache: false,
        beforeSend: function(){
          h2o_global.showGlobalSpinnerNode();
          $('div.ajax-error').html('').hide();
        },
        success: function(html){
          h2o_global.hideGlobalSpinnerNode();
          $('#edit_item #status_message').remove();
          $('#annotation_edit .dynamic').css('padding', '10px').html(html).show();
          //$('<div>').attr('id', 'annotation_edit').addClass('tab_panel new_annotation').html(html).appendTo($('#edit_item'));
        },
        error: function(xhr){
          h2o_global.hideGlobalSpinnerNode();
          $('div.ajax-error').show().append(xhr.responseText);
        }
      });
  }, //end anntotation dialog

  initPlaylistItemAddButton: function(){
    $('.add-collage-button').live('click', function(e) {
      e.preventDefault();
      var link_start = $('input[name=link_start]').val();
      var link_end = $('input[name=link_end]').val();
      var host_collage = $('input[name=host_collage]').val();
      var itemId = $(this).attr('id').split('-')[1];
      collages.submitCollageLink(itemId, link_start, link_end, host_collage);
    });
  },

  initKeywordSearch: function(){
    $('#link_search').live('click', function(e) {
      e.preventDefault();
      $.ajax({
        method: 'GET',
        url: h2o_global.root_path() + 'collage_links/embedded_pager',
        beforeSend: function(){
           h2o_global.showGlobalSpinnerNode();
        },
        data: {
            keywords: $('#collage-keyword-search').val(),
            link_start: $('#edit_item input[name=link_start]').val(),
            link_end: $('#edit_item input[name=link_end]').val(),
            host_collage: $('#edit_item input[name=host_collage]').val(),
            text: $('#edit_item input[name=text]').val()
        },
        dataType: 'html',
        success: function(html){
          h2o_global.hideGlobalSpinnerNode();
          $('#link_edit .dynamic').html(html);
        },
        error: function(xhr){
          h2o_global.hideGlobalSpinnerNode();
        }
      });
    });
  },
  
  submitCollageLink: function(linked_collage, link_start, link_end, host_collage){
    $.ajax({
      type: 'POST',
      cache: false,
      data: {collage_link: {
        linked_collage_id: linked_collage,
        host_collage_id: host_collage,
        link_text_start: link_start,
        link_text_end: link_end
        }
      },
      url: h2o_global.root_path() + 'collage_links/create',
      success: function(results){
        h2o_global.hideGlobalSpinnerNode();
        $('#link_edit .dynamic,#annotation_edit .dynamic').hide().html('');
        $('#link_edit #search_wrapper_outer').hide();
        $('#edit_item').append($('<div>').attr('id', 'status_message').html('Link Created'));
        collages.markupCollageLink(results.collage_link);
      }
    });
  },
  openCollageLinkForm: function(url_path, data){
    $.ajax({
      type: 'GET',
      url: h2o_global.root_path() + url_path,
      cache: false,
      beforeSend: function(){
         h2o_global.showGlobalSpinnerNode();
      },
      data: data,
      dataType: 'html',
      success: function(html){
        h2o_global.hideGlobalSpinnerNode();
        $('#link_edit .dynamic').html(html).show();
      }
    });
  }
};

$(document).ready(function(){
  if($('.singleitem').length > 0){
    h2o_global.showGlobalSpinnerNode();
    collages.observeSelectors();

    $('.toolbar, #buttons').css('visibility', 'visible');
    $('#cancel-annotation').live('click', function(e){
      e.preventDefault();
      var el = $('#' + $(this).data('id'));
      el.find('a.annotation_tip').tipsy("hide");
      el.find('a.annotation_tip').remove();
      new_annotation_start = '';
      new_annotation_end = '';
    });

    $.each(annotations, function(i, el) {
      clean_annotations[i] = $.parseJSON(el).annotation;
      collages.markupAnnotation(clean_annotations[i], layer_color_map, true);
    });

    unlayered_tts = $('div.article tt:not(.a)');
    if(!$('tt#t1').is('.a')) {
      $('<a class="unlayered-ellipsis" id="unlayered-ellipsis-1" data-id="1" href="#">[...]</a>').insertBefore($('tt#t1'));
    }

    $.each(collage_links, function(i, el) {
      clean_collage_links[i] = el.collage_link;
      collages.markupCollageLink(clean_collage_links[i]);
    });

    collages.observeAnnotationListeners();
    collages.observeToolListeners();
    collages.observePrintListeners();
    collages.observeLayerColorMapping();
    collages.observeHeatmap();
    collages.observeAnnotationEditListeners();
  
    collages.observeStatsListener();

    /* Collage Search */
    collages.initKeywordSearch();
    collages.initPlaylistItemAddButton();

    collages.observeFootnoteLinks();
    h2o_global.hideGlobalSpinnerNode();
    collages.observeViewerToggleEdit();
    collages.observeStatsHighlights();
          
    collages.updateWordCount();

    collages.slideToParagraph();
    collages.observeDeleteInheritedAnnotations();
    collages.observeUpgradeCollage();

    //Must be after onclicks initiated
    if($.cookie('user_id') == null) {
      access_results = { 'can_edit_annotations' : false };
      last_data = original_data;
      collages.loadState();
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

var layer_tools_visibility = '\
<li data-hex="{{hex}}" data-name="{{name}}" data-id="l{{id}}">\
<a class="hide_show shown tooltip l{{id}}" href="#" original-title="Hide the {{name}} layer">HIDE "{{name}}"</a>\
</li>';

var layer_tools_highlights = '\
<li data-hex="{{hex}}" data-name="{{name}}" data-id="l{{id}}">\
<a class="tooltip link-o l{{id}}" href="#" original-title="Highlight the {{name}} Layer">HIGHLIGHT "{{name}}" <span style="background:#{{hex}}" class="indicator"></span></a>\
</li>';
