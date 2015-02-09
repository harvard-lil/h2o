var all_tts;
var annotations;
var original_data = {};
var layer_data;
var collage_id;
var h2o_annotator;
var all_collage_data = {};

var collages = {
  listenToRecordAnnotatedItemState: function() {
    //do nothing
  },
  clean_layer: function(layer_name) {
    return layer_name.replace(/ /, 'whitespace').replace(/\./, 'specialsymbol');
  },
  set_highlights: function(data) {
    //do nothing
  },
  set_highlights_for_highlight_only: function(data) {
    //do nothing
  },
  rehighlight: function() {
    //do nothing
  },
  updateWordCount: function() {
    //do nothing
  },
  getHexes: function() {
    return $('<div>');
  },
  loadState: function(collage_id, data) {
    export_functions.highlightAnnotatedItem(collage_id, data.highlights, data.highlight_only_highlights);

    var cannotations = all_collage_data["collage" + collage_id].annotations;
    $.each(cannotations, function(i, ann) {
      var annotation = $.parseJSON(ann);
      if(annotation.annotation != '') {
        $('<span>').addClass('annotation-content annotation-content-' + annotation.id).html(annotation.annotation).insertAfter($('.annotation-' + annotation.id + ':last'));
      } else if(annotation.link !== undefined && annotation.link !== null) {
        var link_html = '<a href="' + annotation.link + '">' + annotation.link + '</a>'; 
        $('<span>').addClass('annotation-content annotation-content-' + annotation.id).html(link_html).insertAfter($('.annotation-' + annotation.id + ':last'));
      }
    });

    if($('#printannotations').val() == 'yes') {
      $('#collage' + collage_id + ' span.annotation-content').show();
    }
    if($('#hiddentext').val() == 'show') {
      $('#collage' + collage_id + ' .layered-ellipsis-hidden').hide();
      $('#collage' + collage_id + ' .original_content,#collage' + collage_id + ' .annotation-hidden').show();
    }
    if($('#printhighlights').val() == 'all') {
      export_functions.highlightAnnotatedItem(collage_id, all_collage_data["collage" + collage_id].layer_data, all_collage_data["collage" + collage_id].highlights_only);
    }
  }
};

var export_functions = {
  initiate_collage_data: function(id, data) {
    all_collage_data["collage" + id] = data;
  },
  init_hash_detail: function() {
    if(document.location.hash.match('fontface')) {
      var vals = document.location.hash.replace('#', '').split('-');
      for(var i in vals) {
        var font_values = vals[i].split('=');
        if(font_values[0] == 'fontsize' || font_values[0] == 'fontface') {
          $('#' + font_values[0]).val(font_values[1]);
        }
      }
    }
  },
  init_user_settings: function() {
    $('#printhighlights').val('original');

    if($.cookie('user_id') !== null) {
      if($.cookie('print_titles') == 'false') {
        $('#printtitle').val('no');
        $('h1').hide();
        $('.playlists h3').hide();
      }
      if($.cookie('print_dates_details') == 'false') {
        $('#printdetails').val('no');
        $('.details').hide();
      }
      if($.cookie('print_paragraph_numbers') == 'false') {
        $('#printparagraphnumbers').val('no');
        $('.paragraph-numbering').hide();
        $('.collage-content').css('padding-left', '0px');
      }
      if($.cookie('print_annotations') == 'true') {
        $('#printannotations').val('yes');
      }
      if($.cookie('hidden_text_display') == 'true') {
        $('#hiddentext').val('show');
      }
      if($.cookie('print_highlights') == 'none') {
        $('#printhighlights').val('none');
        $('.collage-content').each(function(i, el) {
          var id = $(el).data('id');
          export_functions.highlightAnnotatedItem(id, {}, {});
        });
      } else if($.cookie('print_highlights') == 'all') {
        $('#printhighlights').val('all');
      }
      $('#fontface').val($.cookie('print_font_face'));
      $('#fontsize').val($.cookie('print_font_size'));
    }
  },
  init_listeners: function() {
    $('#fontface').selectbox({
      className: "jsb", replaceInvisible: true
    }).change(function() {
      export_functions.setFontPrint();
    });
    $('#fontsize').selectbox({
      className: "jsb", replaceInvisible: true
    }).change(function() {
      export_functions.setFontPrint();
    });
    $('#printannotations').selectbox({
      className: "jsb", replaceInvisible: true
    }).change(function() {
      if($(this).val() == 'yes') {
        $('.annotation-content').show();
      } else {
        $('.annotation-content').hide();
      }
    });

    $('#printtitle').selectbox({
      className: "jsb", replaceInvisible: true
    }).change(function() {
      var choice = $(this).val();
      if (choice == 'yes') {
        $('h1').show();
        $('.playlists h3').show();
      }
      else {
        $('h1').hide();
        $('.playlists h3').hide();
      }
    });
    $('#printdetails').selectbox({
      className: "jsb", replaceInvisible: true
    }).change(function() {
      var choice = $(this).val();
      if (choice == 'yes') {
        $('.details').show();
      }
      else {
        $('.details').hide();
      }
    });
    $('#printparagraphnumbers').selectbox({
      className: "jsb", replaceInvisible: true
    }).change(function() {
      var choice = $(this).val();
      if (choice == 'yes') {
        $('.paragraph-numbering').show();
        $('.collage-content').css('padding-left', '50px');
      }
      else {
        $('.paragraph-numbering').hide();
        $('.collage-content').css('padding-left', '0px');
      }
    });
    $('#hiddentext').selectbox({
      className: "jsb", replaceInvisible: true
    }).change(function() {
      var choice = $(this).val();
      if(choice == 'show') {
        $('.layered-ellipsis-hidden').hide();
        $('.original_content,.annotation-hidden').show();
      } else if(choice == 'hide') {
        $('.layered-ellipsis-hidden').show();
        $('.annotation-hidden').hide();
        $('.annotation-hidden').parents('.original_content').filter(':not(.original_content *):not(:has(.annotator-hl:visible,.layered-ellipsis:visible))').hide();
        $.each($('.layered-ellipsis-hidden'), function(a, b) {
          var annotation_id = $(b).data('layered');
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
    });
    $('#printhighlights').selectbox({
      className: "jsb", replaceInvisible: true
    }).change(function() {
      var choice = $(this).val();
      $('#highlight_styles').text('');
      if(choice == 'original') {
        $('.collage-content').each(function(i, el) {
          var id = $(el).data('id');
          var data = all_collage_data["collage" + id];
          export_functions.highlightAnnotatedItem(id, data.highlights, data.highlights_only);
        });
      } else if(choice == 'all') {
        $('.collage-content').each(function(i, el) {
          var id = $(el).data('id');
          export_functions.highlightAnnotatedItem(id, all_collage_data["collage" + id].layer_data, all_collage_data["collage" + id].highlights_only);
        });
      } else {
        $('.collage-content').each(function(i, el) {
          var id = $(el).data('id');
          export_functions.highlightAnnotatedItem(id, {}, {});
        });
      }
    });

    $('.wrapper').css('margin-top', $('#print-options').height() + 15);
    $('#print-options').css('opacity', 1.0);
    export_functions.setFontPrint();
  },
  setFontPrint: function() {
    var font_size = $('#fontsize').val();
    var font_face = $('#fontface').val();
    var base_font_size = h2o_fonts.base_font_sizes[font_face][font_size];

    var base_selector = 'body#' + $('body').attr('id') + ' .singleitem';
    if(font_face == 'verdana') {
      $.rule(base_selector + " * { font-family: Verdana, Arial, Helvetica, Sans-serif; font-size: " + base_font_size + 'px; }').appendTo('#additional_styles');
    } else {
      $.rule(base_selector + " * { font-family: '" + h2o_fonts.font_map[font_face] + "'; font-size: " + base_font_size + 'px; }').appendTo('#additional_styles');
    }
    $.rule(base_selector + ' *.scale1-5 { font-size: ' + base_font_size*1.5 + 'px; }').appendTo('#additional_styles');
    $.rule(base_selector + ' *.scale1-4 { font-size: ' + base_font_size*1.4 + 'px; }').appendTo('#additional_styles');
    $.rule(base_selector + ' *.scale1-3 { font-size: ' + base_font_size*1.3 + 'px; }').appendTo('#additional_styles');
    $.rule(base_selector + ' *.scale1-2 { font-size: ' + base_font_size*1.2 + 'px; }').appendTo('#additional_styles');
    $.rule(base_selector + ' *.scale1-1 { font-size: ' + base_font_size*1.1 + 'px; }').appendTo('#additional_styles');
    $.rule(base_selector + ' *.scale0-9 { font-size: ' + base_font_size*0.9 + 'px; }').appendTo('#additional_styles');
    $.rule(base_selector + ' *.scale0-8,' + base_selector + ' *.scale0-8 * { font-size: ' + base_font_size*0.8 + 'px; }').appendTo('#additional_styles');
  },
  loadAnnotator: function(id) {
    annotations = all_collage_data["collage" + id].annotations || {};
    layer_data = all_collage_data["collage" + id].layer_data || {};
    highlights_only = all_collage_data["collage" + id].highlights_only || {};

    var elem = $('#collage' + id + ' div.article');
    var factory = new Annotator.Factory();
    var Store = Annotator.Plugin.fetch('Store');
    var h2o = Annotator.Plugin.fetch('H2O');

    h2o_annotator = factory.addPlugin(h2o, layer_data, highlights_only).getInstance();
    h2o_annotator.attach(elem, 'print_export_annotation');
    h2o_annotator.plugins.H2O.loadAnnotations(id, annotations, true);
  },
  filteredLayerData: function(layer_data) {
    var filtered_layer_data = {}; 
    $.each(layer_data, function(i, j) {
      filtered_layer_data[collages.clean_layer(i)] = j;
    });
    return filtered_layer_data;
  },
  highlightAnnotatedItem: function(collage_id, highlights, highlights_only) {
    if(highlights === undefined) {
      highlights = {};
    }
    layer_data = export_functions.filteredLayerData(all_collage_data["collage" + collage_id].layer_data);
 
    // Removing highlights from tagged + color
    var keys = new Array();
    $.each(highlights, function(i, j) {
      keys.push(collages.clean_layer(i));
    });
    $.each(layer_data, function(i, j) {
      if($.inArray(i, keys) == -1) {
        $('#collage' + collage_id + ' .layer-' + i).removeClass('highlight-' + i);
      }
    });

    //Removing highlights from color only
    $.each(all_collage_data["collage" + collage_id].highlights_only || [], function(i, j) {
      if($.inArray(j, highlights_only) == -1) {
        $('#collage' + collage_id + ' .layer-hex-' + j).removeClass('highlight-hex-' + j);
      }
    });

    $.each(highlights || [], function(i, j) {
      $('#collage' + collage_id + ' .annotator-wrapper .layer-' + collages.clean_layer(i)).addClass('highlight-' + collages.clean_layer(i));
    });
    $.each(highlights_only || [], function(i, j) {
      $('#collage' + collage_id + ' .annotator-wrapper .layer-hex-' + j).addClass('highlight-hex-' + j);
    });

    var total_selectors = new Array();
    $.each($('#collage' + collage_id + ' .annotator-wrapper .annotator-hl'), function(i, child) {
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
        var opacity = 0.6 / key_length;
        $.each(unique_layers, function(key, value) {
          var color_combine;
          if(key.match(/^hex-/)) {
            color_combine = $.xcolor.opacity(current_hex, key.replace(/^hex-/, ''), opacity);
          } else {
            color_combine = $.xcolor.opacity(current_hex, layer_data[key], opacity);
          }
          current_hex = color_combine.getHex();
        });
        $.rule('#collage' + collage_id + ' ' + selector + ' { border-bottom: 2px solid ' + current_hex + '; }').appendTo('#highlight_styles');
        updated[selector] = 1;
      }
    }
    var keys_arr = new Array();
    $.each(updated, function(key, value) {
      keys_arr.push(key);
    });
  }
};

$(document).ready(function(){
  export_functions.init_hash_detail();
  export_functions.init_user_settings();

  $('article sub, article sup, div.article sub, div.article sup').addClass('scale0-8');
  $('article h1, div.article h1').addClass('scale1-4');
  $('article h2, div.article h2').addClass('scale1-3');
  $('article h3, div.article h3').addClass('scale1-2');
  $('article h4, div.article h4').addClass('scale1-1');

  $('div.article *:not(.paragraph-numbering)').addClass('original_content');
  $('.collage-content').each(function(i, el) {
    export_functions.loadAnnotator($(el).data('id')); 
  });

  export_functions.init_listeners();
});
