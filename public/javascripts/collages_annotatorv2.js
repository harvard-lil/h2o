var st_annotator;
var unlayered_count = 0;
var recorded_annotations;
var new_annotation_start = '';
var new_annotation_end = '';
var just_hidden = 0;
var layer_info = {};
var last_annotation = 0;
var annotation_position = 0;
var head_offset;
var update_unlayered_end = 0;
var collage_id;
var heatmap_display = false;
var original_annotations;

$.extend({
  clean_layer: function(layer_name) {
    return layer_name.replace(/\./, 'specialsymbol');
  },
  revert_clean_layer: function(layer_name) {
    return layer_name.replace(/specialsymbol/, '.');
  },
  highlightHeatmap: function() {
    $('.layered-empty').removeClass('layered-empty');

	  $.rule('.annotator-wrapper .annotator-hl { background-color: rgba(255,0,0,0.3); }').appendTo('#additional_styles');
  },
  rehighlight: function() {
	  $('.layered-empty').removeClass('layered-empty');
	  var total_selectors = new Array();
	  $.each($('.annotator-wrapper .annotator-hl'), function(i, child) {
	    var this_selector = '';
	    var parent_class = '';
	    var classes = $(child).attr('class').split(' ');
	    for(var j = 0; j<classes.length; j++) {
	      if(classes[j].match(/^highlight/)) {
	        parent_class += '.' + classes[j];
	      }
	    }
	    if(parent_class != '') {
	      this_selector = parent_class;
	    }
	    $.each($(child).parentsUntil('.annotator-wrapper'), function(j, node) {
	      if($(node).is('span.annotator-hl')) {
	        var selector_class = '';
	        var classes = $(node).attr('class').split(' ');
	        for(var j = 0; j<classes.length; j++) {
	          if(classes[j].match(/^highlight/)) {
	            selector_class += '.' + classes[j];
	         }
	        }
	        if(selector_class != '') {
	          this_selector = selector_class + ' ' + this_selector;
	        }
	      }
	    });
	    if(this_selector != '') {
	      total_selectors.push(this_selector.replace(/ $/, ''));
	    }
	  });
	  var updated = {};
	  for(var i = 0; i<total_selectors.length; i++) {
	    updated[total_selectors[i]] = 0;
	  }
	  for(var i = 0; i<total_selectors.length; i++) {
	    var selector = total_selectors[i];
	    if(updated[selector] == 0) {
	      var unique_layers = {};
	      var layer_count = 0;
	      var x = selector.split(' ');
	      for(var a = 0; a < x.length; a++) {
	        var y = x[a].split('.');
	        for(var b = 0; b < y.length; b++) {
	          var key = y[b].replace(/^highlight-/, '');
	          if(key != '') {
	            unique_layers[key] = 1;
	          }
	        }
	      }
	      var current_hex = '#FFFFFF';
	      var key_length = 0;
	      $.each(unique_layers, function(key, value) {
	        key_length++;
	      });
	      var opacity = 0.4 / key_length;
	      $.each(unique_layers, function(key, value) {
	        var color_combine = $.xcolor.opacity(current_hex, layer_data[$.revert_clean_layer(key)], opacity);
	        current_hex = color_combine.getHex();
	      });
	      $.rule(selector + ' { background-color: ' + current_hex + '; }').appendTo('#additional_styles');
	      updated[selector] = 1;
	    }
	  }
	  var keys_arr = new Array();
	  $.each(updated, function(key, value) {
	    keys_arr.push(key);
	  });
    if(keys_arr.length > 0) {
	    $('.annotator-hl:not(' + keys_arr.join(',') + '):not(' + keys_arr.join(',') + '> .annotator-hl)').addClass('layered-empty');
    } else {
      $('.annotator-hl').addClass('layered-empty');
    }
  },
  observeDeleteInheritedAnnotations: function () {
    $('#delete_inherited_annotations').on('click', function(e) {
      e.preventDefault();

      $.ajax({
        type: 'GET',
        cache: false,
        dataType: 'JSON',
        url: $.rootPath() + 'collages/' + $.getItemId() + '/delete_inherited_annotations',
        beforeSend: function(){
          $.showGlobalSpinnerNode();
        },
        success: function(data){
          var stored_annotations = st_annotator.dumpAnnotations();
          $.each(stored_annotations, function(_i, a) {
            if(a.cloned) {
              st_annotator.plugins.H2O.specialDeleteAnnotation(a);
            }
          });
          $.updateWordCount();
          $.hideGlobalSpinnerNode();
          $('#inherited_h,#inherited_span').remove();
        },
        error: function() {
          $.hideGlobalSpinnerNode();
        }
      });
    });
  },
  initiate_annotator: function(can_edit) {
    collage_id = $.getItemId();
    $('div.article').data('collage_id', collage_id).data('original_data', original_data).annotator({ readOnly: !can_edit }).annotator('addPlugin', 'H2O', layer_data).annotator('addPlugin', 'Store', {
      prefix: '/annotations',
      urls: {
        create: '/create',
        read: '/annotations/:id',
        update: '/:id',
        destroy: '/:id',
        search: '/search'
      }
    });
  },
  collage_afterload: function(results) {
    if($.browser.msie && $.browser.version < 9.0) {
      return;
    }

    if(results.can_edit_annotations) {
      $.initiate_annotator(true);  
      $('.requires_edit').animate({ opacity: 1.0 });
    } else {
      $.initiate_annotator(false);  
      $('.requires_edit').remove();
    }
    if(results.can_edit_description) {
      $('.edit-action').animate({ opacity: 1.0 });
    } else {
      $('.edit-action').remove();
    }
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
  observeFootnoteLinks: function() {
    $.each($('div.article a.footnote'), function(i, el) {
      $(el).attr('href', unescape($(el).attr('href')));
      $(el).attr('name', unescape($(el).attr('name')));
    });

    $('div.article a.footnote').click(function() {
      var href = $(this).attr('href').replace('#', '');
      var link = $("div.article a[name='" + href + "']:first");
      if(link.size()) {
        if(!link.is(':visible')) {
          $('.unlayered-ellipsis-' + link.parents('.unlayered').first().data('unlayered')).click();
        }
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
      if($('#layers_highlights li[data-hex="' + item.hex + '"]').size()) {
        node = $('<span>').addClass('inactive').css({ 'background' : '#' + item.hex });
      }
      hexes.append(node);
    });
    return hexes;
  },
  observeLayerColorMapping: function() {
    $(document).delegate('.hexes a', 'click', function() {
      if($(this).hasClass('inactive')) {
        return false;
      }
      $(this).parent().siblings('.hex_input').find('input').val($(this).data('value'));
      $(this).siblings('a.active').removeClass('active');
      $(this).addClass('active');
      return false;
    });
    $(document).delegate('#add_new_layer', 'click', function() {
      var new_layer = $('<li class="annotator-item annotator-h2o_layer"><p>Enter Layer Name <input type="text" name="new_layer" /></p><p class="hex_input">Choose a Color<input type="hidden" name="new_layer_list[][hex]" /></p><a href="#" class="remove_layer">Cancel &raquo;</a></div>');
      var hexes = $.getHexes();
      hexes.insertBefore(new_layer.find('.remove_layer'));
      new_layer.insertBefore($('.annotator-h2o_layer_button'));
      return false;
    });
    $(document).delegate('.remove_layer', 'click', function() {
      $(this).parent().remove();
      return false;
    });
  },
  observeHeatmap: function() {
    $(document).delegate('#heatmap_toggle:not(.inactive,.activated)', 'click', function(e) {
      e.preventDefault();
      $.showGlobalSpinnerNode();
      last_data = $.retrieveState();
      $('.unlayered,.annotator-hl').show();
      $.each($('#layers_highlights a'), function(i, el) {
        if($(el).text().match(/^UNHIGHLIGHT/)) {
          $(el).click();
        }
      });
      $('#text-layer-tools').addClass('inactive').css('opacity', 0.3);
      original_annotations = annotations;
      annotations = heatmap;
      heatmap_display = true;
      st_annotator.plugins.H2O.loadAnnotations();
      $.highlightHeatmap();
      $('#heatmap_toggle').addClass('activated');
      $.hideGlobalSpinnerNode();
    });
    $(document).delegate('#heatmap_toggle.activated', 'click', function(e) {
      e.preventDefault();
      $.showGlobalSpinnerNode();
      var stored_annotations = st_annotator.dumpAnnotations();
      var collage_id = $.getItemId();
      $.each(stored_annotations, function(_i, a) {
        if(a.collage_id != collage_id) {
          st_annotator.plugins.H2O.specialDeleteAnnotation(a);
        }
      });
      annotations = original_annotations; 
      heatmap_display = false;
      $('#text-layer-tools').removeClass('inactive').css('opacity', 1.0);
      $('#heatmap_toggle').removeClass('activated');
	    $.rule('.annotator-wrapper .annotator-hl', '#additional_styles').remove();

      $.rehighlight();
      $.loadState($.getItemId(), last_data);
      $.hideGlobalSpinnerNode();
    });
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
    $(document).delegate("#buttons a.btn-a:not(.btn-a-active)", 'click', function(e) {
      e.preventDefault();
      if($(this).hasClass('inactive')) {
        return;
      }
      var top_pos = $(this).position().top + $(this).height() + 10;
      var left_pos = $(this).width() - 208;
      $('.text-layers-popup').css({ position: 'absolute', top: top_pos, left: left_pos, "z-index": 1 }).fadeIn(200);
      $(this).addClass("btn-a-active");
    });
    $(document).delegate("#buttons a.btn-a-active", 'click', function(e) {
      e.preventDefault();
      $('.text-layers-popup').fadeOut(200);
      $(this).removeClass("btn-a-active");
    });
    $(document).delegate('#quickbar_tools:not(.active)', 'click', function(e) {
      e.preventDefault();
      var top_pos = $(this).position().top + $(this).height() + 8;
      var left_pos = $(this).position().left - 198 + $(this).width();
      $('.text-layers-popup').css({ position: 'fixed', top: top_pos, left: left_pos, "z-index": 5 }).fadeIn(200);
      $(this).addClass('active');
    });
    $(document).delegate('#quickbar_tools.active', 'click', function(e) {
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
      $('.unlayered,.annotator-hl').show();
      $.loadState($.getItemId(), last_data);
    });
    $('#full_text').click(function(e) {
      e.preventDefault();
      $.showGlobalSpinnerNode();
      $('.unlayered,.annotator-hl').show();
      $('.unlayered-control-start,.unlayered-control-end,.unlayered-ellipsis,.layered-control-start,.layered-control-end,.layered-ellipsis').hide();
      $.each($('#layers a.hide_show'), function(i, el) {
        $(el).html('HIDE "' + $(el).parent().data('name') + '"');
      });
      $.hideShowUnlayeredOptions();
      $.hideGlobalSpinnerNode();
    });

    $('#show_unlayered a').click(function(e) {
      e.preventDefault();
      $.showGlobalSpinnerNode();
      $('.unlayered').show();
      $('.unlayered-ellipsis,.unlayered-control-start,.unlayered-control-end').hide();
      $.hideShowUnlayeredOptions();
      $.hideGlobalSpinnerNode();
    });
    $('#hide_unlayered a').click(function(e) {
      e.preventDefault();
      $.showGlobalSpinnerNode();
      $('.unlayered,.unlayered-control-start,.unlayered-control-end').hide();
      $('.unlayered-ellipsis').show();
      $.hideShowUnlayeredOptions();
      $.hideGlobalSpinnerNode();
    });

    $(document).delegate('#layers .hide_show', 'click', function(e) {
      e.preventDefault();
      $.showGlobalSpinnerNode();

      var el = $(this);
      var layer = $(this).parent().data('name');
      var clean_layer = $.clean_layer(layer);
      if(el.html().match("SHOW ")) {
        $('.layer-' + clean_layer).parents('.original_content').show();
        $('.layer-' + clean_layer).show();
        $('.layered-ellipsis.layer-' + clean_layer).hide();

        el.html('HIDE "' + layer + '"');
      } else {
        $('.layer-' + clean_layer).hide();
        $('.layered-ellipsis.layer-' + clean_layer).css('display', 'inline-block');
        $('.layer-' + clean_layer).parents('.original_content').filter(':not(.original_content *):not(:has(.unlayered:visible,.annotator-hl:visible,.layered-ellipsis:visible))').hide();
        el.html('SHOW "' + layer + '"');
      }

      $.hideGlobalSpinnerNode();
    });

    $(document).delegate('#layers_highlights .link-o', 'click', function(e) {
      e.preventDefault();
      var layer = $(this).parent().data('name');
      var clean_layer = $.clean_layer(layer);
      var hex = $(this).parent().data('hex');
        
      var text_node = $(($(this).contents())[0]);
      var new_node;
      if($(this).data('highlight') === undefined || $(this).data('highlight') == false) {
        $('span.layer-' + clean_layer).addClass('highlight-' + clean_layer);
        $(this).data('highlight', true);
        new_node = document.createTextNode('UNHIGHLIGHT "' + layer + '"');
      } else {
        $('span.layer-' + clean_layer).removeClass('highlight-' + clean_layer);
        $(this).data('highlight', false);
        new_node = document.createTextNode('HIGHLIGHT "' + layer + '"');
      }
      text_node.replaceWith(new_node);
      $.rehighlight();
    });
  },
  observePrintListeners: function() {
    $('#fixed_print,#quickbar_print').click(function(e) {
      e.preventDefault();
      $('#collage_print').submit();
    });
    $('form#collage_print').submit(function() {
      var data = $.retrieveState();

      if($('#heatmap_toggle').hasClass('activated')) {
        data.load_heatmap = true;
      }

      data.font_size = $('#fontsize a.active').data('value');
      data.font_face = $('#fontface a.active').data('value');
      $('#state').val(JSON.stringify(data));
    });
  },
  recordCollageState: function(data, show_message) {
    var words_shown = 0;
    var b = $('.unlayered:not(.unlayered > .unlayered):not(.paragraph-numbering):not(:empty):visible').text().replace(/[^\w ]/g, "");
    if(b != '') {
      words_shown += b.split( /\s+/ ).length;
    }

    var c = $('.annotator-hl:not(.annotator-hl > .annotator-hl):not(.paragraph-numbering):not(:empty):visible').text().replace(/[^\w ]/g, "");
    if(c != '') {
      words_shown += c.split( /\s+/ ).length;
    }

    $.ajax({
      type: 'POST',
      cache: false,
      data: {
        readable_state: data,
        words_shown: words_shown
      },
      url: $.rootPath() + 'collages/' + $.getItemId() + '/save_readable_state',
      success: function(results){
        //if(show_message) {
          //$('#autosave').html('Updated at: ' + results.time);
        //}
      }
    });
  },
  updateWordCount: function() {
    var unlayered = 0;
    var b = $('.unlayered:not(.unlayered > .unlayered):not(.paragraph-numbering):not(:empty)').text().replace(/[^\w ]/g, "");
    if(b != '') {
      unlayered = b.split( /\s+/ ).length;
    }

    var layered = 0;
    var c = $('.annotator-hl:not(.annotator-hl > .annotator-hl):not(.paragraph-numbering):not(:empty)').text().replace(/[^\w ]/g, "");
    if(c != '') {
      layered = c.split( /\s+/ ).length;
    }

    $('#word_stats').html(layered + ' layered, ' + unlayered + ' unlayered');
  },
  retrieveState: function() {
    var data = { highlights: {} };
    $('.unlayered-ellipsis:visible').each(function(i, el) {
      data['unlayered_' + $(el).data('unlayered')] = $(el).data('unlayered');
    });
    $('.layered-ellipsis:visible').each(function(i, el) {
      data['layered_' + $(el).data('layered')] = $(el).data('layered');
    });
    $.each($('.link-o'), function(i, el) {
      if($(el).text().match('UNHIGHLIGHT')) {
        data.highlights[$(el).parent().data('name')] = $(el).parent().data('hex');
      }
    });

    return data;
  },
  listenToRecordCollageState: function() {
    setInterval(function(i) {
      if(heatmap_display) {
        return;
      }
      var data = $.retrieveState();
      if(JSON.stringify(data) != JSON.stringify(last_data)) {
        last_data = data;
        $.recordCollageState(JSON.stringify(data), true);
      }
    }, 1000); 
  },
  loadState: function(collage_id, data) {
    $.each(data, function(i, e) {
      if(i.match(/^unlayered/)) {
        $('.unlayered-' + e).hide();
        $('.unlayered-ellipsis-' + e).show();
      } else if(i.match(/^layered/)) {
        $('.annotation-' + e).hide();
        $('.layered-ellipsis-' + e).show();
      } else if(i.match(/^highlights/)) {
        $.each(e, function(j, k) {
          $("ul#layers_highlights li[data-name='" + j + "'] a").click();
        });
      }
    });
    $.hideShowUnlayeredOptions();
    if(access_results.can_edit_annotations) {
      $('#edit_toggle').click();
      $('.default-hidden').css('color', '#000');
    } else {
      $.checkForPanelAdjust();
    }
    if($.cookie('scroll_pos')) {
      $(window).scrollTop($.cookie('scroll_pos'));
      $.cookie('scroll_pos', null);
    }
  }, 
  resetParentDisplay: function(els) {
    var parents = els.parentsUntil('div.article');
    parents.removeClass('no_visible_children');
    parents.filter(':not(:has(.layered-control,.control-divider,.unlayered-ellipsis:visible,tt:visible))').addClass('no_visible_children');
  },
  observeAddCollageAsAnnotation: function(){
    $(document).delegate('.add-collage-button', 'click', function(e) {
      e.preventDefault();
      $('#linked_collage_id').val($(this).data('collage_id'));
      $('.annotator-save').click();
    });
  },
  initKeywordSearch: function(){
    $(document).delegate('#collage_link_search', 'click', function(e) {
      e.preventDefault();
      $.ajax({
        method: 'GET',
        url: $.rootPath() + 'collage_links/embedded_pager',
        beforeSend: function(){
           $.showGlobalSpinnerNode();
        },
        data: {
            keywords: $('#collage_search input').val()
        },
        dataType: 'html',
        success: function(html){
          $.hideGlobalSpinnerNode();
          $('#collage_links').html(html);
          if($('#collage_links .add-collage-button').size() == 0) {
            $('#collage_links').append($('<p>').html('No collages found.').attr('id', 'no_collages_found'));
          }
        },
        error: function(xhr){
          $.hideGlobalSpinnerNode();
        }
      });
    });
  },
  openCollageLinkForm: function(url_path) {
    $.ajax({
      type: 'GET',
      url: $.rootPath() + url_path,
      cache: false,
      beforeSend: function(){
         $.showGlobalSpinnerNode();
      },
      data: {},
      dataType: 'html',
      success: function(html){
        $.hideGlobalSpinnerNode();
        $('#collage_links').html(html);
      }
    });
  }
});

$(document).ready(function(){
  if($.browser.msie && $.browser.version < 9.0) {
    $('<p id="nonsupported_browser">Collage annotation functionality is not supported by your browser. Please upgrade to IE9 or greater.</p>').dialog({ 
      title: "Non-Supported Browser"
    }).dialog('open');
    $('.ui-dialog-titlebar-close').remove();
    $('body').css('overflow', 'hidden');
    $('.main_wrapper').css({ opacity: 0.2 });
    return;
  }

  $.showGlobalSpinnerNode();

  $('.toolbar, #buttons').css('visibility', 'visible');
  $.observeToolListeners();
  $.observeLayerColorMapping();
  $.observePrintListeners();
  $.observeHeatmap();
  $.observeDeleteInheritedAnnotations();
  $.initKeywordSearch();
  $.observeAddCollageAsAnnotation();

  $.observeFootnoteLinks();
  $.hideGlobalSpinnerNode();
  $.observeStatsHighlights();
  $.slideToParagraph();
});

var layer_tools_visibility = '\
<li data-hex="{{hex}}" data-name="{{layer}}" data-id="l{{id}}">\
<a class="hide_show shown tooltip l{{id}}" href="#" original-title="Hide the {{layer}} layer">HIDE "{{layer}}"</a>\
</li>';

var layer_tools_highlights = '\
<li data-hex="{{hex}}" data-name="{{layer}}" data-id="l{{id}}">\
<a class="tooltip link-o l{{id}}" href="#" original-title="Highlight the {{layer}} Layer">HIGHLIGHT "{{layer}}" <span style="background:#{{hex}}" class="indicator"></span></a>\
</li>';

