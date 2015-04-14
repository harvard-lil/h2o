var all_tts;
var annotations;
var original_data = {};
var layer_data;
var h2o_annotator;
var all_collage_data = {};
var tocId = 'toc';

var collages = {
  listenToRecordAnnotatedItemState: function() {},
  set_highlights: function(data) {},
  set_highlights_for_highlight_only: function(data) {},
  rehighlight: function() {},
  updateWordCount: function() {},
  clean_layer: function(layer_name) {
    //Note: Implemented in multiple areas in our javascript/ruby
    if(layer_name === undefined) {
      return '';
    }
    return layer_name.replace(/ /g, 'whitespace').replace(/\./g, 'specialsymbol').replace(/'/g, 'apostrophe').replace(/\(/g, 'leftparen').replace(/\)/g, 'rightparen').replace(/,/g, 'c0mma').replace(/\&/g, 'amp3r');
  },
  getHexes: function() {
    return $('<div>');
  },
  loadState: function(collage_id, data) {
    export_functions.highlightAnnotatedItem(collage_id, data.highlights, data.highlight_only_highlights);

    var cannotations = all_collage_data["collage" + collage_id].annotations;
    $.each(cannotations, function(i, ann) {
      var annotation = $.parseJSON(ann);
      if(annotation.annotation != '' && !annotation.hidden && !annotation.error && !annotation.discussion && !annotation.feedback) {
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
    show_toc: function(toc_levels) {
        var toc_node = $('#' + tocId);
        toc_node.remove();
        export_functions.generate_toc(toc_levels);
        toc_node.show();  //do we need this?
        $('#toc_container').show();
    },
    hide_toc: function() {
        var toc_node = $('#' + tocId);
        toc_node.remove();
        //toc_node.hide();
        $('#toc_container').hide();
    },
    generate_toc: function(toc_levels) {
        var toc_nodes = export_functions.build_branch();
        export_functions.wrap_toc(toc_nodes);
    },
    toc_max_depth: function() {
        //console.log( 'TMD: ' + $('#toc_levels').val() );
        return $('#toc_levels').val();
    },
    build_branch: function(parent, depth) {
        //$depth indicates the current depth of $parent
        //Returns nested array of nodes that are children of parent, including any children of those children

        //wkhtmltopdf cannot handle default argument values in function definitions
        parent = typeof parent !== 'undefined' ? parent : $(':root');
        depth = typeof depth !== 'undefined' ? depth : 1;

        var max_depth = export_functions.toc_max_depth();
        //console.log( 'BB.max_depth: ' + max_depth);
        if (depth > max_depth) {
            //TODO: This should never happen and can probably be removed completely
            //console.log('max depth reached!'); 
            return null; 
        }
        
        var nodes = [];
        parent.toc_level = depth-1;
        children = parent.find('.playlists > ul').first().children();

        //Can we just push parent onto nodes and let the children.each call noop?
        if (!children.length) { 
            return parent; 
        } else {
            //This is where we save a parent that does have children
            nodes.push( parent );
        }
        
        children.each(function () {
            var child = $(this);
            child.toc_level = depth;
            //console.log( get_text(child) );
            //if we are currently at our max depth, return this kid rather than make a recursive call.
            //nodes.push( (depth == max_depth) ? child : export_functions.build_branch( child, depth+1 ) );
            if (depth == max_depth) {
                nodes.push( child );
            }
            else {
                nodes.push( export_functions.build_branch( child, depth+1 ) );
            }
        });
        return nodes;
    },
    wrap_toc: function(nodes) {
        var toc_root_node = $('#toc_container');
        var flat_results = export_functions.flatten(nodes)
        var toc = $('<ol/>', { id: tocId });
        
        for(var i = 0; i<flat_results.length; i++) {
            var toc_line = export_functions.get_text(flat_results[i])
            //console.log( toc_line );
            toc.append($('<li/>', { html: toc_line }));
            toc.appendTo(toc_root_node);
        }
    },
    get_text: function( node ) {
        //TODO: Clean this up and use less raw HTML
        var header_node = node.children('h3').first();;
        var content = $(header_node).children('.hcontent');
        var anchor = $(header_node).children('.number').children('a');
        var toc_line = '<span class="toc_hcontent toc_level' + node.toc_level;
        toc_line += '"><a href="#' + anchor.attr('name') + '">';
        toc_line += content.text() + '</a></span>';

        return toc_line;
    },
    flatten: function(arr) {
        //TODO: exit safely if arr is null
        return arr.reduce(function (flat, toFlatten) {
            return flat.concat(Array.isArray(toFlatten) ? export_functions.flatten(toFlatten) : toFlatten);
        }, []);
    },
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
    title_debug: function(msg) {
        $("h1").text( $("h1").text() + ", " + msg );
    },
    init_user_settings: function() {
        //export_functions.title_debug('IUS firing');
        //$("h1").text( $("h1").text() + "," + 'IUS firing' );
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
      $('#toc_levels').val($.cookie('toc_levels'));
      if($.cookie('toc_levels') !== null) {
        //console.log( 'IUS.toc_levels: ' + $.cookie('toc_levels') );
        export_functions.show_toc($.cookie('toc_levels'));
      }
    }
  },
  init_listeners: function() {
    $('#toc_levels').selectbox({
      className: "jsb", replaceInvisible: true
    }).change(function() {
      //BUG: This might be locking in $('#toc_levels').val() to whatever it was when the listener was defined
      export_functions.setTocLevels($('#toc_levels').val());
    });
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
    setTocLevels: function(toc_levels) {
        if (toc_levels && toc_levels.match(/\d+/)) {
            export_functions.show_toc(toc_levels);
        } else {
            export_functions.hide_toc();
        }
        //Just control the cookie from this select box until we add a user preferences control for it
        //That will also fix the path, which is incorrect for this cookie at the moment
        $.cookie('toc_levels', toc_levels);
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
    var report_options = { "report": false, "feedback": false, "discuss": false, "respond": false };
    h2o_annotator = factory.addPlugin(h2o, layer_data, highlights_only, report_options).getInstance();
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
    var collageCssId = '#collage' + collage_id;
    highlights = highlights || {};
    highlights_only = highlights_only || [];
    layer_data = export_functions.filteredLayerData(all_collage_data["collage" + collage_id].layer_data);

    // Removing highlights from tagged + color
    var keys = new Array();
    $.each(highlights, function(i, j) {
      keys.push(collages.clean_layer(i));
    });
    $.each(layer_data, function(i, j) {
      if($.inArray(i, keys) == -1) {
        $(collageCssId + ' .layer-' + i).removeClass('highlight-' + i);
      }
    });

    //Removing highlights from color only
    $.each(all_collage_data["collage" + collage_id].highlights_only || [], function(i, j) {
      if($.inArray(j, highlights_only) == -1) {
        $(collageCssId + ' .layer-hex-' + j).removeClass('highlight-hex-' + j);
      }
    });

    $.each(highlights, function(i, j) {
      var layer_name = collages.clean_layer(i);
      $(collageCssId + ' .annotator-wrapper .layer-' + layer_name).addClass('highlight-' + layer_name);
    });
    $.each(highlights_only, function(i, j) {
      $(collageCssId + ' .annotator-wrapper .layer-hex-' + j).addClass('highlight-hex-' + j);
    });

    var total_selectors = new Array();
    $.each($(collageCssId + ' .annotator-wrapper .annotator-hl'), function(i, child) {
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
          var hex_arg = key.match(/^hex-/) ? key.replace(/^hex-/, '') : layer_data[key];
          current_hex = $.xcolor.opacity(current_hex, hex_arg, opacity).getHex();
        });
        $.rule(collageCssId + ' ' + selector + ' { border-bottom: 2px solid ' + current_hex + '; }').appendTo('#highlight_styles');
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
