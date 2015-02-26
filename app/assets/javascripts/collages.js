var h2o_annotator;
var unlayered_count = 0;
var just_hidden = 0;
var layer_info = {};
var last_annotation = 0;
var annotation_position = 0;
var head_offset;
var update_unlayered_end = 0;
var collage_id;
var original_annotations;

h2o_global.collage_afterload = function(results) {
  if($.browser.msie && $.browser.version < 9.0) {
    return;
  }
  if(!results.can_destroy) {
    $('#description .delete-action').remove();
  }
  if(results.can_edit) {
    collages.initiate_annotator(true);  
    $('.requires_edit').animate({ opacity: 1.0 });
    $('.edit-action').animate({ opacity: 1.0 });
  } else {
    collages.initiate_annotator(false);  
    $('.requires_edit').remove();
    $('.edit-action').remove();
  }
  h2o_global.setFontClasses();
};

var collages = {
  clean_layer: function(layer_name) {
    if(layer_name === undefined) {
      return '';
    }
    return layer_name.replace(/ /g, 'whitespace').replace(/\./g, 'specialsymbol').replace(/'/g, 'apostrophe').replace(/\(/g, 'leftparen').replace(/\)/g, 'rightparen').replace(/,/g, 'c0mma').replace(/\&/g, 'amp3r');
  },
  revert_clean_layer: function(layer_name) {
    return layer_name.replace(/whitespace/g, ' ').replace(/specialsymbol/g, '.').replace(/apostrophe/g, "'").replace(/rightparen/g, ')').replace(/leftparen/g, '(').replace(/c0mma/g, ',').replace(/amp3r/, '&');
  },
  turn_on_initial_highlight: function(attr, value) {
    $('li[data-' + attr + '="' + value + '"] .toggle').toggles({ on: true, height: 15, width: 40 });
    $('li[data-' + attr + '="' + value + '"] .toggle .toggle-on').addClass('active');
    $('li[data-' + attr + '="' + value + '"] .toggle .toggle-off').removeClass('active');
    $('li[data-' + attr + '="' + value + '"] .toggle-show_hide').toggles({ on: true, height: 15, width: 55, text: { on: 'SHOW', off: 'HIDE' }});
    $('li[data-' + attr + '="' + value + '"] .toggle-show_hide .toggle-on').addClass('active');
    $('li[data-' + attr + '="' + value + '"] .toggle-show_hide .toggle-off').removeClass('active');
  },
  set_highlights: function(data) {
    var color_combine = $.xcolor.opacity('#FFFFFF', data.hex, 0.4);

    current_hex = color_combine.getHex();
    var clean_layer = collages.clean_layer(data.layer);
    $.rule('.indicator-highlight-' + clean_layer + ' { background-color: ' + current_hex + '; }').appendTo('#additional_styles');
    $('label[for=layer-' + clean_layer + ']').css('background-color', current_hex);
  },
  set_highlights_for_highlight_only: function(highlight) {
    var clean_layer = collages.clean_layer(highlight);
    $('label[for=highlight-only-' + clean_layer + ']').css('background-color', highlight);
  },
  rehighlight: function() {
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
          var hex;
          if(key.match(/^hex-/)) {
            hex = key.replace(/^hex-/, '');
          } else {
            hex = layer_data[collages.revert_clean_layer(key)];
          }
	        var color_combine = $.xcolor.opacity(current_hex, hex, opacity);
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
  },
  initiate_annotator: function(can_edit) {
    $('div.article *:not(.paragraph-numbering)').addClass('original_content');

    collage_id = h2o_global.getItemId();
    var elem = $('div.article');

    var factory = new Annotator.Factory();
    var Store = Annotator.Plugin.fetch('Store');
    var h2o = Annotator.Plugin.fetch('H2O');

    h2o_annotator = factory.setStore(Store, { 
      prefix: '/collages/' + h2o_global.getItemId() + '/annotations',
      urls: {
        create: '',
        read: '/annotations/:id',
        update: '/:id',
        destroy: '/:id',
        search: '/search'
      }
    }).addPlugin(h2o, layer_data, highlights_only).getInstance();
    if(!can_edit) {
      $('.article').addClass('read_only');
      h2o_annotator.options.readOnly = true;
    }
    h2o_annotator.attach(elem);
    h2o_annotator.plugins.H2O.loadAnnotations(h2o_global.getItemId(), raw_annotations.single, true);
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
          var annotation = link.parent().find('.annotator-hl');
          if(annotation.size()) {
            var _id = annotation.first().data('annotation-id');
            $('.layered-ellipsis-' + _id).hide();
            $('.annotation-' + _id).show();
            $('.annotation-' + _id).parents('.original_content').show();
            $('.layered-control-start-' + _id + ',.layered-control-end-' + _id).css('display', 'inline-block');
            h2o_annotator.plugins.H2O.updateAllAnnotationIndicators();
          }
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
      var node = $('<a href="#">' + item.hex + '</a>').css({ 'background' : '#' + item.hex });
      if($('#layers_highlights li[data-hex="' + item.hex + '"]').size()) {
        node = $('<a>').html(item.hex).addClass('inactive').css({ 'background' : '#' + item.hex });
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
      $(this).parent().siblings('.hex_input').find('input').val($(this).text());
      $(this).siblings('a.active').removeClass('active');
      $(this).addClass('active');
      return false;
    });
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
      $('.text-layers-popup').css({ position: 'fixed', top: top_pos, left: left_pos, "z-index": 1001 }).fadeIn(200);
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

    $(document).delegate('.toggle-show_hide', 'toggle', function(e, active) {
      var layer;
      if($(e.target).parent().hasClass('user_layer')) {
        layer = $(e.target).parent().data('name');
      } else {
        layer = 'hex-' + $(e.target).parent().data('hex');
      }
      if(active) {
        $('.layered-ellipsis.' + layer).hide();
        $('.layered-control-start.' + layer + ',.layered-control-end.' + layer).css('display', 'inline-block');
        $('.annotator-hl.layer-' + layer + ',a.indicator-highlight-' + layer).show();
        $('.annotator-hl.layer-' + layer).parents('.original_content').filter(':not(.original_content *):not(:has(.annotator-hl:visible,.layered-ellipsis:visible))').show();
      } else {
        $('.layered-ellipsis.' + layer).show(); 
        $('.layered-control-start.' + layer + ',.layered-control-end.' + layer).hide();
        $('.annotator-hl.layer-' + layer + ',a.indicator-highlight-' + layer).hide();
        $('.annotator-hl.layer-' + layer).parents('.original_content').filter(':not(.original_content *):not(:has(.annotator-hl:visible,.layered-ellipsis:visible))').hide();
      }
      h2o_annotator.plugins.H2O.updateAllAnnotationIndicators();
    });

    $('#show_text_edits .toggle').on('toggle', function(e, active) {
      if(active) {
        $('.layered-ellipsis').hide();
        $('.layered-control-start,.layered-control-end').css('display', 'inline-block');
        $('.annotator-hl,.original_content,.annotation-indicator-highlights').show();
        $.each($('.user_layer'), function(i, el) {
          $(el).find('.toggle-show_hide .toggle-inner').css({ "margin-left": 0 });
          $(el).find('.toggle-show_hide .toggle-on').addClass('active');
          $(el).find('.toggle-show_hide .toggle-off').removeClass('active');
        });
      } else {
        $('.annotation-hidden').hide();
        $.each($('.icon-adder-show'), function(i, j) {
          var annotation_id = $(j).data('id');
          $('.layered-ellipsis-' + annotation_id).css('display', 'inline-block');
          $('.layered-control-start-' + annotation_id + ',.layered-control-end-' + annotation_id).hide();
          $('.annotation-' + annotation_id).parents('.original_content').filter(':not(.original_content *):not(:has(.annotator-hl:visible,.layered-ellipsis:visible))').hide();
          $.each($('.annotation-' + annotation_id).parents('.original_content').filter(':not(.original_content *)'), function(i, j) {
            var has_text_node = false;
            $.each($(j).contents(), function(k, l) {
              if(l.nodeType == 3 && $(l).text() != ' ') {
                has_text_node = true;
              }
            });
            if(has_text_node) {
              $(j).show();
            }
          });
        });
      }
      h2o_annotator.plugins.H2O.updateAllAnnotationIndicators();
    });

    $('#show_comments .toggle').on('toggle', function(e, active) {
      if(active) {
        $('.annotation-indicator-annotate span:not(.icon-adder-annotate)').show();
        $('.annotation-indicator-annotate span:not(.icon-adder-annotate) .icon-edit').show();
      } else {
        $('.annotation-indicator-annotate span:not(.icon-adder-annotate)').hide();
      }
    });
    $('#show_links .toggle').on('toggle', function(e, active) {
      if(active) {
        $('.annotation-indicator-link span:not(.icon-adder-link)').show();
        $('.annotation-indicator-link span:not(.icon-adder-link) .icon-edit').show();
      } else {
        $('.annotation-indicator-link span:not(.icon-adder-link)').hide();
      }
    });

    $('#highlight_all_li .toggle').on('toggle', function(e, active) {
      if(active) {
        $.each($('.user_layer, .highlight_only_layer'), function(i, el) {
          var layer;
          if($(el).hasClass('user_layer')) {
            layer = $(el).data('name');
          } else {
            layer = 'hex-' + $(el).data('hex');
          }
          $(el).find('.toggle-inner').css({ "margin-left": 0 });
          $('span.layer-' + layer).addClass('highlight-' + layer);
          $(el).find('.toggle .toggle-off').removeClass('active');
          $(el).find('.toggle .toggle-on').addClass('active');
        });
      } else {
        $.each($('.user_layer, .highlight_only_layer'), function(i, el) {
          var layer;
          if($(el).hasClass('user_layer')) {
            layer = $(el).data('name');
          } else {
            layer = 'hex-' + $(el).data('hex');
          }
          $(el).find('.toggle-inner').css({ "margin-left": -25 });
          $('span.layer-' + layer).removeClass('highlight-' + layer);
          $(el).find('.toggle .toggle-on').removeClass('active');
          $(el).find('.toggle .toggle-off').addClass('active');
        });
      }
      collages.rehighlight();
    });
    $(document).delegate('#layers_highlights li.user_layer .toggle', 'toggle', function(e, active) {
      var layer = $(this).parent().data('name');
      if(active) { 
        $('span.layer-' + layer).addClass('highlight-' + layer);

        if($('.user_layer .toggle-on.active').length == $('.user_layer .toggle-on').length) {
          $('#highlight_all_li .toggle-inner').css({ "margin-left": 0 });
          $('#highlight_all_li .toggle-off').removeClass('active');
          $('#highlight_all_li .toggle-on').addClass('active');
        }
      } else {
        $('span.layer-' + layer).removeClass('highlight-' + layer);
        if($('.user_layer .toggle-on.active').length == 0) {
          $('#highlight_all_li .toggle-inner').css({ "margin-left": -25 });
          $('#highlight_all_li .toggle-on').removeClass('active');
          $('#highlight_all_li .toggle-off').addClass('active');
        }
      }
      collages.rehighlight();
    });
    $(document).delegate('#layers_highlights li.highlight_only_layer .toggle', 'toggle', function(e, active) {
      var hex = $(this).parent().data('hex');
      if(active) { 
        $('span.layer-hex-' + hex).addClass('highlight-hex-' + hex);
        if($('.highlight_layer .toggle-on.active').length == $('.user_layer .toggle-on').length) {
          $('#highlight_all_li .toggle-inner').css({ "margin-left": 0 });
          $('#highlight_all_li .toggle-off').removeClass('active');
          $('#highlight_all_li .toggle-on').addClass('active');
        }
      } else {
        $('span.layer-hex-' + hex).removeClass('highlight-hex-' + hex);
        if($('.highlight_layer .toggle-on.active').length == 0) {
          $('#highlight_all_li .toggle-inner').css({ "margin-left": -25 });
          $('#highlight_all_li .toggle-on').removeClass('active');
          $('#highlight_all_li .toggle-off').addClass('active');
        }
      }
      collages.rehighlight();
    });
  },
  observePrintListeners: function() {
    $('#fixed_print,#quickbar_print').click(function(e) {
      e.preventDefault();
      $('#collage_print').submit();
    });
    $('form#collage_print').submit(function() {
      $('#state').val(JSON.stringify(collages.retrieveState()));
    });
  },
  recordAnnotatedItemState: function(data, show_message) {
    var words_shown = 0;

    var b = $('.original_content:not(.original_content > .original_content):not(.paragraph-numbering):not(:empty):visible').text().replace(/[^\w ]/g, "");
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
      url: h2o_global.root_path() + 'collages/' + h2o_global.getItemId() + '/save_readable_state',
      success: function(results){
        //Do nothing
      }
    });
  },
  retrieveState: function() {
    var data = { highlights: {}, hide_tags: {}, highlight_only_highlights: [] };
    $.each($('#layers_highlights li.user_layer'), function(i, el) {
      if($(el).find('.toggle .toggle-on').hasClass('active')) {
        data.highlights[$(el).data('name')] = $(el).data('hex');
      }
      if(!$(el).find('.toggle-show_hide .toggle-on').hasClass('active')) {
        data.hide_tags[$(el).data('name')] = true;
      }
    });
    $.each($('#layers_highlights li.highlight_only_layer'), function(i, el) {
      if($(el).find('.toggle .toggle-on').hasClass('active')) {
        data.highlight_only_highlights.push($(el).data('hex'));
      }
    });
    if($('#show_text_edits .toggle-inner .toggle-on').hasClass('active')) {
      data.show_text_edits = true;
    }
    if($('#show_comments .toggle-inner .toggle-on').hasClass('active')) {
      data.show_comments = true;
    }
    if($('#show_links .toggle-inner .toggle-on').hasClass('active')) {
      data.show_links = true;
    }

    return data;
  },
  listenToRecordAnnotatedItemState: function() {
    setInterval(function(i) {
      var data = collages.retrieveState();
      if(JSON.stringify(data) != JSON.stringify(last_data)) {
        last_data = data;
        collages.recordAnnotatedItemState(JSON.stringify(data), true);
      }
    }, 1000); 
  },
  loadState: function(collage_id, data) {
    $.each(data, function(i, e) {
      if(i == 'show_text_edits' || i == 'show_comments' || i == 'show_links') {
        $('#' + i + ' .toggle').addClass('activated').toggles({ on: true, height: 15, width: 40 });
        $('#' + i + ' .toggle-on').addClass('active');
        $('#' + i + ' .toggle-off').removeClass('active');
        if(i == 'show_text_edits') {
          $('.layered-ellipsis').hide();
          $('.layered-control-start,.layered-control-end').css('display', 'inline-block');
          $('.annotation-hidden,.original_content').show();
        } else if(i == 'show_comments') {
          $('.annotation-indicator-annotate span:not(.icon-adder-annotate)').show();
          $('.annotation-indicator-annotate span:not(.icon-adder-annotate) .icon-edit').show();
        } else if(i == 'show_links') {
          $('.annotation-indicator-link span:not(.icon-adder-link)').show();
          $('.annotation-indicator-link span:not(.icon-adder-link) .icon-edit').show();
        }
      } else if(i == 'highlights') {
        $.each(e, function(j, hex) {
          $('li[data-name="' + j + '"] .toggle').addClass('activated').toggles({ on: true, height: 15, width: 40 });
          $('li[data-name="' + j + '"] .toggle-on').addClass('active');
          $('li[data-name="' + j + '"] .toggle-off').removeClass('active');
          var clean_layer = collages.clean_layer(j);
          $('span.layer-' + clean_layer).addClass('highlight-' + clean_layer);
        });
        collages.rehighlight();
      } else if(i == 'hide_tags') {
        $.each(e, function(layer, v) {
          $('.layered-ellipsis.' + layer).show(); 
          $('.layered-control-start.' + layer + ',.layered-control-end.' + layer).hide();
          $('.annotator-hl.layer-' + layer + ',a.indicator-highlight-' + layer).hide();
          $('.annotator-hl.layer-' + layer).parents('.original_content').filter(':not(.original_content *):not(:has(.annotator-hl:visible,.layered-ellipsis:visible))').hide();
          $('li[data-name="' + layer + '"] .toggle-show_hide').addClass('activated').toggles({ height: 15, width: 55, text: { on: 'SHOW', off: 'HIDE' }});
        });
      } else if(i == 'highlight_only_highlights') {
        $.each(e, function(j, hex) {
          $('li[data-hex="' + hex + '"] .toggle').addClass('activated').toggles({ on: true, height: 15, width: 40 });
          $('li[data-hex="' + hex + '"] .toggle-on').addClass('active');
          $('li[data-hex="' + hex + '"] .toggle-off').removeClass('active');
          $('span.layer-hex-' + hex).addClass('highlight-hex-' + hex);
        });
        collages.rehighlight();
      }
    });
       
    if($('.user_layer .toggle-on.active').length == $('.user_layer .toggle').length) {
      $('#highlight_all_li .toggle').addClass('activated').toggles({ on: true, height: 15, width: 40 });
      $('#highlight_all_li .toggle-inner').css({ "margin-left": 0 });
      $('#highlight_all_li .toggle-off').removeClass('active');
      $('#highlight_all_li .toggle-on').addClass('active');
    }

    $('.paragraph-numbering').css('opacity', 1.0);
    h2o_annotator.plugins.H2O.updateAllAnnotationIndicators();
    if(access_results.can_edit) {
      $('#edit_toggle').click();
      $('.default-hidden').css('color', '#000');
    } else {
      h2o_global.checkForPanelAdjust();
    }
    if($.cookie('scroll_pos')) {
      $(window).scrollTop($.cookie('scroll_pos'));
      $.cookie('scroll_pos', null);
    }
    if($.cookie('user_id') !== null && $.cookie('default_show_comments') == 'true') {
      $('#show_comments .toggle').addClass('activated').toggles({ on: true, height: 15, width: 40 });
      $('#show_comments .toggle-on').addClass('active');
      $('#show_comments .toggle-off').removeClass('active');
      $('.annotation-indicator-annotate span:not(.icon-adder-annotate)').show();
      $('.annotation-indicator-annotate span:not(.icon-adder-annotate) .icon-edit').show();
    }
    if($.cookie('user_id') !== null && $.cookie('default_show_paragraph_numbers') == 'false') {
      $('.singleitem div.article > *').css('margin-left', '0.0em');
      $('.paragraph-numbering').css('opacity', 0.0);
      h2o_annotator.plugins.H2O.updateAllAnnotationIndicators();
    }

    $.each($('.toggle-show_hide:not(.activated)'), function(i, el) {
      $(el).toggles({ on: true, height: 15, width: 55, text: { on: 'SHOW', off: 'HIDE' }});
      $(el).find('.toggle-off').removeClass('active');
      $(el).find('.toggle-on').addClass('active');
    });
    $('.toggle:not(.activated)').toggles({ height: 15, width: 40 });
  } 
};

$(document).ready(function(){
  if(!($('.singleitem').length > 0 && $('body').attr('id') == 'collages_show')) {
    return;
  }

  if($.browser.msie && $.browser.version < 9.0) {
    $('<p id="nonsupported_browser">Annotation functionality is not supported by your browser. Please upgrade to IE9 or greater.</p>').dialog({ 
      title: "Non-Supported Browser"
    }).dialog('open');
    $('.ui-dialog-titlebar-close').remove();
    $('body').css('overflow', 'hidden');
    $('.main_wrapper').css({ opacity: 0.2 });
    return;
  }

  h2o_global.showGlobalSpinnerNode();

  $('.toolbar, #buttons').css('visibility', 'visible');
  collages.observeToolListeners();
  collages.observeLayerColorMapping();
  collages.observePrintListeners();

  collages.observeFootnoteLinks();
  h2o_global.hideGlobalSpinnerNode();
  collages.observeStatsHighlights();
  collages.slideToParagraph();


  $(window).resize(function() {
     if($(window).width() < 1150) {
       $('.edit-annotate').css('width', $(window).width() * 0.25 - 25);
     } else {
       $('.edit-annotate').css('width', 295);
     }
  });
});

var layer_tools_highlights = '\
<li class="user_layer highlight_layer" data-hex="{{hex}}" data-name="{{clean_layer}}">\
<span class="layer_name">{{layer}}</span><span class="indicator" style="background-color:#{{hex}};"></span>\
<div class="toggle toggle-light"></div>\
<div class="toggle-show_hide toggle-light"></div>\
</li>';

var layer_tools_highlight_only = '\
<li class="highlight_only_layer highlight_layer" data-hex="{{hex}}">\
<span class="indicator" style="background-color:#{{hex}};"></span>\
<div class="toggle toggle-light"></div>\
<div class="toggle-show_hide toggle-light"></div>\
</li>';
