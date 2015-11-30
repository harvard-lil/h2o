var phunk_start, phunk_last, phunk_end;
var highlight_css_cache = {};
var annotations;
var original_data = {};
var layer_data;
var collage_id;
var tocId = 'toc';
var h2o_annotator;
var h2o_global = { slideToAnnotation: function() {} };
var all_collage_data = {};
var page_width_inches = 8.5;
var ignore_theme_change = false;
var cookies = [
    'hidden_text_display',
    'print_annotations',
    'print_font_face',
    'print_font_size',
    'print_highlights',
    'print_margin_size',
    'print_paragraph_numbers',
    'print_titles',
    'toc_levels',
]
var h2o_themes = {
    'default' : {
        '#toc_levels': '5',
        '#printtitle': 'yes',
        '#printparagraphnumbers': 'no',
        '#fontface': 'garamond',
        '#fontsize': 'medium',
        '#margin-top': '0.75in',
        '#margin-right': '0.75in',
        '#margin-bottom': '0.75in',
        '#margin-left': '0.75in',
    },
    'classic' : {
        '#toc_levels': '5',
        '#printtitle': 'yes',
        '#printparagraphnumbers': 'no',
        '#fontface': 'garamond',
        '#fontsize': 'large',
        '#margin-top': '1.0in',
        '#margin-right': '1.5in',
        '#margin-bottom': '1.0in',
        '#margin-left': '0.75in',
    },
    'modern' : {
        '#toc_levels': '5',
        '#printtitle': 'yes',
        '#printparagraphnumbers': 'no',
        '#fontface': 'futura',
        '#fontsize': 'medium',
        '#margin-top': '0.75in',
        '#margin-right': '0.75in',
        '#margin-bottom': '0.75in',
        '#margin-left': '0.75in',
    },
};

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
    return layer_name
      .replace(/ /g, 'whitespace')
      .replace(/\./g, 'specialsymbol')
      .replace(/'/g, 'apostrophe')
      .replace(/\(/g, 'leftparen')
      .replace(/\)/g, 'rightparen')
      .replace(/,/g, 'c0mma')
      .replace(/\&/g, 'amp3r');
  },
  getHexes: function() {
    return $('<div>');
  },
  loadState: function(collage_id, data) {
    //NOTE: This is called once for EACH collage. This means that anything
    //in this function that does not constrain itself to this specific collage
    //is doing too much work and is therefore at risk of slowing down very
    //large playlists with a lot of annotations. (Although I have not tested
    //by how much.)
    //TODO: For the code in this function that just shows|hides elements,
    //there exists some kind of race condition that prevents us from just
    //relying completely on a select's .change() handler. $('#printhighlights')
    //is probably the best example of how I just could never make that work.
    //console.log('~~~~~~~~ loadState for collage_id: ' + collage_id);
    var idString = "collage" + collage_id;
    var idCss = "#" + idString;

    export_functions.updateLoadingDisplay();

    //TODO: How does this really differ from the highlightAnnotatedItem
    //at the end of this method or in the #printhighlights.change() handler?
    export_highlighter.highlightAnnotatedItem(
      collage_id,
      data.highlights,
      data.highlight_only_highlights
    );

    export_functions.injectAnnotations(all_collage_data[idString].annotations);
    /*
      TODO: move all of these to loadAllAnnotationsComplete, with consideration
      to our future plans to load X annotations directly (as done here) and >X
      annotations asynchronously. We could look at how many annotations are .done_loading
      and if it's < X, fire the wrapper function that we'll throw the below code into.
      We can probably make idCss an options argument to that function so it can
      behave as a targeted thing or a shotgun-approach kind of thing. We could also
      add filters [.filter(':hidden') or its faster equiv] to the selectors used so it
      only gets called on the right elements.
      Related Idea: We can call this idea once for every collage < the Xth one, or
      we can just call it once when we hit the Xth one. The next call to this would be
      the last one, when the "all done with every annotation" callback fires. I like
      calling it every collage < the Xth one, keeping X less than 10.
     */
    /*
//The code below this line in this method takes up ~40% of the load time of playlist #22368.
    //annotations (really comments here) and links are hidden by CSS by default
    if($('#printannotations').val() == 'yes') {
      //$('#printannotations').change();
      //This could be changed to use the Word style we are now defining
      $(idCss + ' .annotation-content').filter(':not(.annotation-link)').show();
    }
    if($('#printlinks').val() == 'yes') {
      $('#printlinks').change();
    }
    if($('#hiddentext').val() == 'show') {
      //$('#hiddentext').change();
      $(idCss + ' .layered-ellipsis-hidden').hide();
      $(idCss + ' .original_content,' + idCss + ' .annotation-hidden').show();
    }

    //We need to fire this .change() here (doing it in document.ready is not enough)
    // to correctly control highlights for all export formats. Moving this somewhere
    // where it will be called less frequently (in order to reduce overhead when
    // loading a very large number of collages/annotations) will very likely break
    // something subtle.
    $('#printhighlights').change();

    //if($('#printhighlights').val() == 'all') {
      //We don't need this here now that the above .change is getting called.
       // export_highlighter.highlightAnnotatedItem(
       //   collage_id,
       //   all_collage_data[idString].layer_data,
       //   all_collage_data[idString].highlights_only
       // );
    //}
    */
  }
};

var table_of_contents = {
    set_toc: function(levels) {
        var toc_node = $('#' + tocId);
        toc_node.remove();
        if (levels) {
            table_of_contents.generate_toc(levels);
            $('#toc-container').show();
        } else {
            $('#toc-container').hide();
        }
    },
    generate_toc: function(toc_levels) {
        var toc_nodes = table_of_contents.build_toc_branch();
        var flat_results = table_of_contents.flatten(toc_nodes)
        var toc = $('<ol/>', { id: tocId });
        var toc_root_node = $('#toc-container');
        for(var i = 0; i<flat_results.length; i++) {
          var toc_line = table_of_contents.toc_entry_text(flat_results[i]);
          toc.append($('<li/>', { html: toc_line }));
          toc.appendTo(toc_root_node);
        }
    },
    build_toc_branch: function(parent, depth) {
        parent = parent || $(':root');
        depth = depth || 1;
        var max_depth = $('#toc_levels').val();
        var nodes = (depth == 1) ? [] : [parent];

        parent.find('.playlists > ul').first().children().each(function () {
            var child = $(this);
            child.toc_level = depth;

            if (depth == max_depth) {
                nodes.push( child );
            }
            else {
                nodes.push( table_of_contents.build_toc_branch( child, depth+1 ) );
            }
        });
        return nodes;
    },
    toc_entry_text: function(node) {
        var header_node = node.children('h' + node.toc_level).first();;
        var content = header_node.children('.hcontent');
        var anchor = header_node.children('.number').children('a');

      return '<span class="toc_level' + node.toc_level + '">' +
        (Array( (node.toc_level-1) * 6 )).join('&nbsp;') +
        '<a href="#' + anchor.attr('name') + '" style="color: #000000">' +
        anchor.text() + ' ' + content.text() + '</a></span>';
    },
    flatten: function(arr) {
        return arr.reduce(function (flat, toFlatten) {
            return flat.concat(Array.isArray(toFlatten) ? table_of_contents.flatten(toFlatten) : toFlatten);
        }, []);
    },
};

var export_functions = {
  updateLoadingDisplay: function() {
    var done_count = 0;
    $.each(all_collage_data, function(id, annotation) {
      if (annotation.done_loading) {
        done_count++;
      }
    });
    $('#anno-load-current').text(done_count);
    $('#anno-load-total').text(Object.keys(all_collage_data).length);
  },
  initiate_collage_data: function(id, data) {
    all_collage_data["collage" + id] = data;
  },
  init_hash_detail: function() {
    if(document.location.hash.match('fontface')) {
      //Note: The "Print" icon link from a playlist sends font info in the URL hash
      var vals = document.location.hash.replace('#', '').split('-');
      for(var i in vals) {
        var font_values = vals[i].split('=');
        var name = font_values[0];
        if ((name == 'fontface' && $.cookie('print_font_face') == null) || (name == 'fontsize' && $.cookie('print_font_size') == null)) {
            $('#' + name).val(font_values[1]).change();
        }
      }
    }
  },
    title_debug: function(msg) {
        $("h1").first().text( $("h1").first().text() + ": " + msg);
        console.log('title_debug-ing the message: ' + msg);
    },
    custom_hide: function(selector) {
        //The export process needs to remove elements, not just hide them.
        if ($.cookie('export_format')) {
            //console.log('custom_hiding: ' + selector);
            $(selector).remove();
        }
    },
    set_titles_visible: function(is_visible) {
        // Hide/Show titles in a crafty way to avoid breaking the wkhtmltopdf TOC
        var new_color = is_visible ? '#000' : '#FFF';
        $('h1').css("color", new_color)
        $('h1 > .number a').css("color", new_color)
    },

    debug_cookies: function() {
        $.each(cookies, function(i, cookie) {
            var c = $.cookie(cookie);
            console.log("Cookie: " + cookie + ": " + (c == null ? '' : c));
        });
    },
    init_missing_cookies: function() {
        return;
      /*
        //TODO: Set cookies the same way they are set in user control panel or don't set them at all
        var defaults = {
            print_margin_left: 'margin-left',
            print_margin_top: 'margin-top',
            print_margin_right: 'margin-right',
            print_margin_bottom: 'margin-bottom',
        };
        Object.keys(defaults).forEach(function(name) {
            $.cookie(name, $.cookie(name) || $('#' + defaults[name]).val() );
        });

        // $('#margin-left').val($.cookie('print_margin_left') || $('#margin-left').val());
        // $('#margin-top').val($.cookie('print_margin_top') || $('#margin-left').val());
        // $('#margin-right').val($.cookie('print_margin_right') || $('#margin-left').val());
        // $('#margin-bottom').val($.cookie('print_margin_bottom') || $('#margin-left').val());
        */
    } ,
    init_user_settings: function() {
      //This function only looks to change the default behavior. I.g. if the
      //default is to *not* show annotations, this function only looks to see if
      //the non-default option for showing annotations has been selected, then
      //it does that work. This can create a bug if you change the default behavior
      //of any of these settings in the view, etc.

      //TODO: Do we need this? This is probably now a no-op since we ditched JSB selectboxes
      $('#printhighlights').val('original');

      if($.cookie('print_titles') == 'false') {
        $('#printtitle').val('no').change();
        export_functions.set_titles_visible(false);
      }
      if($.cookie('print_paragraph_numbers') == 'false') {
          $('#printparagraphnumbers').val('no').change();
        export_functions.custom_hide('.paragraph-numbering');
        //$('.collage-content').css('padding-left', '0px');
      } else {
          //This fixes the bug that left this selectbox showing no/hide when the
          //cookie was actually true and the paragraph numbers were being displayed
          //by default
          $('#printparagraphnumbers').val('yes').change();
      }
      if($.cookie('print_annotations') == 'true') {
        $('#printannotations').val('yes').change();
      }
      if($.cookie('print_links') == 'yes') {
        $('#printlinks').val($.cookie('print_links')).change();
      } else {
        $('#printlinks').val('no').change();
      }
      if($.cookie('hidden_text_display') == 'true') {
        $('#hiddentext').val('show').change();
      }
      if($.cookie('print_highlights') == 'none') {
        $('#printhighlights').val($.cookie('print_highlights')).change();
      }
      if($.cookie('print_highlights') == 'all') {
        $('#printhighlights').val($.cookie('print_highlights')).change();
      }
      if ($.cookie('print_font_face') !== null ) {
          $('#fontface').val($.cookie('print_font_face')).change();
      }
      if ($.cookie('print_font_size') !== null) {
          $('#fontsize').val($.cookie('print_font_size')).change();
      }
      if($.cookie('toc_levels') && $.cookie('export_format') != 'pdf') {
          $('#toc_levels').val($.cookie('toc_levels')).change();
      }

      //These newer options may not have cookies defined yet
      //TODO: finish init_missing_cookies()
      $('#margin-left').val($.cookie('print_margin_left') || $('#margin-left').val());
      $('#margin-top').val($.cookie('print_margin_top') || $('#margin-left').val());
      $('#margin-right').val($.cookie('print_margin_right') || $('#margin-left').val());
      $('#margin-bottom').val($.cookie('print_margin_bottom') || $('#margin-left').val());
      $('#margin-left').change();
  },
  init_theme_picker_listener: function() {
    $('.theme-select-trigger').change(function() {
      if (ignore_theme_change) {
        return;
      }
      $('#theme').val('none');
    });
  },
  init_listeners: function() {
    $('#export-form-submit').click(function(e) {
      e.preventDefault();
      if (!$('#export_format').val()) {
        alert('Please select an export format');
        return false;
      }
      $('#export-form').submit();
    });
    $('#toc_levels').change(function() {
      export_functions.setTocLevels($(this).val());
    });
    $('#fontface').change(function() {
      export_functions.setFontPrint();
    });
    $('#fontsize').change(function() {
      export_functions.setFontPrint();
    });
    $('.margin-select').change(function() {
        export_functions.setMargins();
    });
    $('#printannotations').change(function() {
      var sel = $('.annotation-content').not('.annotation-link');
      if($(this).val() == 'yes') {
        sel.show();
      } else {
        sel.hide();
      }
    });
    $('#printlinks').change(function() {
      //console.log('PL.change firing with val: ' + $(this).val());
      var sel = $('.annotation-link');
      if($(this).val() == 'yes') {
        sel.show();
      } else {
        sel.hide();
      }
    });
      $('#printtitle').change(function() {
        var choice = $(this).val();
        export_functions.set_titles_visible(choice == 'yes');
    });
    $('#printparagraphnumbers').change(function() {
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
    $('#hiddentext').change(function() {
      var choice = $(this).val();
      var ellipses = $('.layered-ellipsis-hidden');

      if(choice == 'show') {
        ellipses.hide();
        $('.original_content,.annotation-hidden').show();
      }
      else if(choice == 'hide') {
        ellipses.show();
        $('.annotation-hidden')
          .hide()
          .parents('.original_content')
          .filter(':not(.original_content *):not(:has(.annotator-hl:visible,.layered-ellipsis:visible))')
          .hide();

        $.each(ellipses, function(a, b) {
          //This is mostly copied from the annotator.sh2o.js annotationsLoaded event handler
          var annotation_id = $(b).data('layered');
          $.each($('.annotation-' + annotation_id).parents('.original_content').filter(':not(.original_content *)'), function(i, j) {
            var has_text_node = false;
            $.each($(j).contents(), function(k, l) {
              if(l.nodeType == 3 && $(l).text() != ' ') {
                has_text_node = true;
                return;
              }
            });
            if(has_text_node) {
              $(j).show();
            }
          });
        });
      }
    });
    $('#printhighlights').change(function() {
        var choice = $(this).val();
        $('.collage-content').each(function(i, el) {
            var id = $(el).data('id');
            var data = all_collage_data["collage" + id];
            var args = null;
            if(choice == 'original') {
                args = [data.highlights, data.highlights_only];
            } else if(choice == 'all') {
                args = [data.layer_data, data.highlights_only];
            } else {  //"none"
                args = [{}, {}];
            }
            export_highlighter.highlightAnnotatedItem(id, args[0], args[1]);
        });
    });
    $('#theme').change(function() {
      ignore_theme_change = true;
      export_functions.setTheme($(this).val());
      //Prevent changed form inputs' listeners from immediately changing this back to None.
      setTimeout(function() {ignore_theme_change = false}, 200);
    });

    //TODO: Maybe we only need this if there is no font face or font size cookie data.
    export_functions.setFontPrint();
  },  //end init_listeners
    setTheme: function(themeId) {
        if (h2o_themes[themeId]) {
            $.each(h2o_themes[themeId], function(sel, value) {
                $(sel).val(value).change();
            });
        }
    },
    setTocLevels: function(toc_levels) {
        table_of_contents.set_toc(toc_levels);
        //Just control the cookie from this select box until we add a user preferences control for it
        //That will also fix the path, which is incorrect for this cookie at the moment
        $.cookie('toc_levels', toc_levels);
    },
    setMargins: function() {
        //TODO SOMEDAY: Set .wrapper margin-top while also accounting for built in margin value it needs for print-options
        var div = $('.wrapper')
        div.css('margin-left', $('#margin-left').val());
        var newWidth = parseFloat(page_width_inches) - (parseFloat($('#margin-left').val()) + parseFloat($('#margin-right').val()));
        div.css('width', newWidth + 'in');
    },
  setFontPrint: function() {
    //TODO: Add timeout to avoid running this twice during an export (when both the
    // font face and font size change pretty much at the same time.)
    var font_face = $('#fontface').val();
    var font_size = $('#fontsize').val();
    var mapped_font_face = h2o_fonts.font_map_fallbacks[font_face];
    var base_font_size = h2o_fonts.base_font_sizes[font_face][font_size];

    $('#fontface_mapped').val(mapped_font_face);
    $('#fontsize_mapped').val(base_font_size + 'px');
    //console.log('faceMapped: ' + $('#fontface_mapped').val());
    //console.log('sizeMapped: ' + $('#fontsize_mapped').val());

    var base = 'body#' + $('body').attr('id') + ' .singleitem';
    var rules = [
      base + ' * { font-family: ' + mapped_font_face + '; font-size: ' + base_font_size + 'px; }',
      base + ' *.scale1-5 { font-size: ' + base_font_size * 1.5 + 'px; }',
      base + ' *.scale1-4 { font-size: ' + base_font_size * 1.4 + 'px; }',
      base + ' *.scale1-3 { font-size: ' + base_font_size * 1.3 + 'px; }',
      base + ' *.scale1-2 { font-size: ' + base_font_size * 1.2 + 'px; }',
      base + ' *.scale1-1 { font-size: ' + base_font_size * 1.1 + 'px; }',
      base + ' *.scale0-9 { font-size: ' + base_font_size * 0.9 + 'px; }',
      base + ' *.scale0-8,' + base + ' *.scale0-8 * { font-size: ' + base_font_size * 0.8 + 'px; }',
    ].join("\n");

    $('#additional_styles').text('');
    $.rule(rules).appendTo('#additional_styles');
  },
  setAnnotationsVisibility: function() {
    //TODO: Can we just call the relevant .change() handlers
    console.log('setAnnotationsVisibility firing');
    //annotations (really comments here) and links are hidden by CSS by default
    if($('#printannotations').val() == 'yes') {
      //$('#printannotations').change();
      //This could be changed to use the Word style we are now defining
      $('.annotation-content').filter(':not(.annotation-link)').show();
    }
    if($('#printlinks').val() == 'yes') {
      $('#printlinks').change();
    }
    if($('#hiddentext').val() == 'show') {
      //$('#hiddentext').change();
      $('.layered-ellipsis-hidden').hide();
      $('.original_content,.annotation-hidden').show();
    }

    //We need to fire this .change() here (doing it in document.ready is not enough)
    // to correctly control highlights for all export formats. Moving this somewhere
    // where it will be called less frequently (in order to reduce overhead when
    // loading a very large number of collages/annotations) will very likely break
    // something subtle.
    $('#printhighlights').change();

    //if($('#printhighlights').val() == 'all') {
    //We don't need this here now that the above .change is getting called.
    // export_highlighter.highlightAnnotatedItem(
    //   collage_id,
    //   all_collage_data[idString].layer_data,
    //   all_collage_data[idString].highlights_only
    // );
    //}
  },
  loadAllAnnotationsComplete: function() {
    //Callback that gets called *once* after all annotations for all collages in
    //a playlist are done loading, including the asynchronous work done by
    //the annotationsLoaded event handler in annotator.sh2o.js. In almost all
    //cases, this will fire after document.ready has run and finished.
    try {
      export_highlighter.applyStyles($.cookie('export_format'));
      export_functions.setAnnotationsVisibility();

      if (!$.cookie('export_format')) {return;}

      // Remove things that would otherwise trip up any of our exporter backends
      $('#print-options').remove();

      // Reset margins because export back-end will manage them
      //NEW: technically, we only need to do this for PDF exports, because PDF
      //exports set margins outside of javascript/HTML completely.
      var div = $('.wrapper');
      div.removeAttr('style');
      //Remove margin previously occupied by #print-options
      div.css('margin-top', '0px');

      //This is a couple of failed attempts at getting annotation comments to display as a block
      //level element in Word.
      //$.each($('.annotation-content').not('.annotation-link'), function(i, node) {
        //var newNode = $('<div>BOOP: ' + node.innerHTML + '</div>');
        //newNode.addClass($(node).attr('class'));
        //$(node).html("<br/>" + $(node).html() + "<br/>");
        //      console.log('new: ' + node.html());
        //$(node).replaceWith(newNode);
      //});

      //NOTE: Does not yet work for footnotes with annotation tags in them, such
      //as footnotes inside hidden text.
      $.each( $('.footnote').parent('p.Item-text'), function(i, node) {
        $(node).removeClass('Item-text');
        $(node).attr('class', 'Footnote ' + $(node).attr('class'));
      });

      //Highlights don't work in DOC, so we fake it with underlined text.
      if ($.cookie('export_format') == 'doc') {
        $.each( $("span[class*=highlight-]"), function(i, node) {
          console.log( $(node).css('text-decoration', 'underline') );
        });
      }
      //Clean up a bunch of DOM nodes that can cause problems in various export formats
      $("body *").filter(":hidden").not("script").remove();

      console.log('loadAllAnnotationsComplete: annotation_load_complete');
    } catch(e) {
      console.log('loadAllAnnotationsComplete warning: ' + e);
    }
    window.status = 'annotation_load_complete';
  },
  loadAllAnnotations: function() {
    //Annotation system looks for original_content class
    $('div.article *:not(.paragraph-numbering)').addClass('original_content');
    $('.collage-content').each(function(i, el) {
      var id = $(el).data('id');
      export_functions.loadAnnotator(id);
    });
  },
  injectAnnotations: function(annotations) {
    //console.log('Injecting ' + Object.keys(annotations).length + ' annotations');
    $.each(annotations, function(i, ann) {
      //NOTE: These elements are all hidden by default as per export.css
      var annotation = $.parseJSON(ann);
      var html;
      var klass = '';
      if(annotation.annotation != '' && !annotation.hidden && !annotation.error && !annotation.discussion && !annotation.feedback) {

        html = annotation.annotation;
      } else if(annotation.link) {
        html = '<a href="' + annotation.link + '">' + annotation.link + '</a>';
        klass = 'annotation-link';
      }
      //BUG: when loading the page, the select can show No when links are actually
      //being displayed. Is this just a refresh issue that we can ignore?
      //NOTE: Annotation-textChar needs to be the first class so Word will see it.
      if (html) {
        var newEl = $('<span>')
          .addClass('Annotation-textChar ' + klass + '  annotation-content annotation-content-' + annotation.id)
          .html(html)
          .insertAfter($('.annotation-' + annotation.id + ':last'));
        //TODO: do the show/hide logic here?
      }
    });
  },
  loadAnnotator: function(id) {
    //TODO: Can we exit fast if the annotation is empty or anything?
    var idString = "collage" + id;
    var collage_data = all_collage_data[idString];
    annotations = collage_data.annotations || {};
    layer_data = collage_data.layer_data || {};
    highlights_only = collage_data.highlights_only || {};

    var factory = new Annotator.Factory();
    var h2o = Annotator.Plugin.fetch('H2O');
    var report_options = { "report": false, "feedback": false, "discuss": false, "respond": false };
    h2o_annotator = factory.addPlugin(h2o, layer_data, highlights_only, report_options).getInstance();
    h2o_annotator.expected_collage_count = h2o_annotator.expected_collage_count || Object.keys(all_collage_data).length;
    h2o_annotator.attach($('#' + idString + ' div.article'), 'print_export_annotation');
    //TODO: delete this merge artifact?    h2o_annotator.attach(elem, 'print_export_annotation');
    h2o_annotator.plugins.H2O.loadAnnotations(id, annotations, true);
  },
  filteredLayerData: function(layer_data) {
    var filtered_layer_data = {};
    $.each(layer_data, function(i, j) {
      filtered_layer_data[collages.clean_layer(i)] = j;
    });
    return filtered_layer_data;
  },

};  //end export_functions

var export_highlighter = {
  highlightAnnotatedItem: function(collage_id, highlights, highlights_only) {
    highlights = highlights || {};
    highlights_only = highlights_only || {};

    var collage_data = all_collage_data["collage" + collage_id];
    var cssId = '#collage' + collage_id;
    layer_data = export_functions.filteredLayerData(collage_data.layer_data);

    // Removing highlights from tagged + color
    var keys = [];
    $.each(highlights, function(i, j) {
      keys.push(collages.clean_layer(i));
    });
    $.each(layer_data, function(i, j) {
      if($.inArray(i, keys) == -1) {
        $(cssId + ' .layer-' + i).removeClass('highlight-' + i);
      }
    });

    //Removing highlights from color only
    $.each(collage_data.highlights_only, function(i, j) {
      if($.inArray(j, highlights_only) == -1) {
        $(cssId + ' .layer-hex-' + j).removeClass('highlight-hex-' + j);
      }
    });

    $.each(highlights, function(i, j) {
      var clean_layer = collages.clean_layer(i);
      $(cssId + ' .annotator-wrapper .layer-' + clean_layer).addClass('highlight-' + clean_layer);
    });

    $.each(highlights_only, function(i, j) {
      $(cssId + ' .annotator-wrapper .layer-hex-' + j).addClass('highlight-hex-' + j);
    });

    var total_selectors = [];
    $.each($(cssId + ' .annotator-wrapper .annotator-hl'), function(i, child) {
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

    export_highlighter.cacheCss(cssId, total_selectors);
  },
  cacheCss: function(cssId, total_selectors) {
    //TODO: I think this is running way too much. I added a single tag to a single
    //collage in my playlist with 4 itmes, and now I'm seeing that tag go through this method 6 times?

    var updated = {};
    $.each(total_selectors, function(i, selector) {
      //TODO: Cache this calculation in a page-level cache object
      if (updated[selector]) {
        return;
      }
      updated[selector] = true;

      var unique_layers = {};
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

      var opacity = 0.6 / Object.keys(unique_layers).length;
      var current_hex = '#FFFFFF';
        $.each(unique_layers, function(key, value) {
          var hex_arg = key.match(/^hex-/) ? key.replace(/^hex-/, '') : layer_data[key];
          current_hex = $.xcolor.opacity(current_hex, hex_arg, opacity).getHex();
        });

        //also, should we remove the cssId b/c it doesn't actually do anything that we care about?
        var full_selector = cssId + ' ' + selector;
        if (!$('#highlight_styles').cssText().match(full_selector)) {
          $.rule(
            full_selector + ' { border-bottom: 2px solid ' + current_hex + '; }'
          ).appendTo('#highlight_styles');
        }
      });

      //Strip ID from highlight-hex-?????? selectors. We don't need them to be
      //collage-specific, and they end up producing fewer unique CSS rules this way.
      var full_selector = selector.match(/^\.highlight-hex-/) ? selector : cssId + ' ' + selector;

      if (!highlight_css_cache[full_selector]) {
        highlight_css_cache[full_selector] = current_hex;
      } else {
        export_highlighter.mismatchedHighlightCheck(full_selector, current_hex);
      }
    }); //end selector loop

  },
  applyStyles: function(export_format) {
    //Force all colors to dark-blue-ish for export so they show up better when printed
    if (!Object.keys(highlight_css_cache).length) {return;}

    var forced_color = export_format ? '#2e00ff' : null;
    var rules = $.map(highlight_css_cache, function(v,sel) {
      return sel + ' {border-bottom: 2px solid ' + (forced_color || v) + ';}';
    }).join("\n");

    $.rule(rules).appendTo('#highlight_styles');
  },
  mismatchedHighlightCheck: function(full_selector, rule) {
    //This probably never happens and is here for debug purposes only. OK to delete.
    if (highlight_css_cache[full_selector] == rule) {return;}
    console.warn('@_@ rule mismatch @_@');
    console.warn('previous: ' + highlight_css_cache[full_selector]);
    console.warn('new rule: ' + rule);
  },
}; //end export_highlighter

$(document).ready(function(){
  //export_functions.debug_cookies();
  //export_functions.init_missing_cookies();
  export_functions.init_listeners();
  export_functions.init_hash_detail();
  export_functions.init_user_settings();

  $('article sub, article sup, div.article sub, div.article sup').addClass('scale0-8');

  // Should h1 actually be scale1-5 here? scale1-5 does seem conspicuously absent
  //   from this list, but it shows up in setFontPrint()
  $('article h1, div.article h1, .new-h1').addClass('scale1-4');
  $('article h2, div.article h2, .new-h2').addClass('scale1-3');
  $('article h3, div.article h3, .new-h3').addClass('scale1-2');
  $('article h4, div.article h4, .new-h4').addClass('scale1-1');

  export_functions.loadAllAnnotations();

    if (!$.cookie('export_format')) {
      export_functions.init_theme_picker_listener();
    }

  //TODO: It could be useful to have a custom_change() method that could optionally
  //apply a prefix to the code that already runs in a select's change handler. That
  //select's current change handler would pass a null prefix, indicating it should
  //operate on the entire document. Conversely, the code in loadState that loads for
  //a single collage would pass an ID prefix to custom_change(), indicating it
  //should only operate under that ID. This lets us re-use the change handler code
  //in a way that is (theoretically) not wildly inefficient.
  //In other news, perhaps those event handlers could be a little faster if they
  //specifically targeted only what they would change, based on visibility. E.g.
  //$('.annotation-link:hidden').show();   //only show the hidden ones. do not try to show the ones already visible
  //FASTER SYNTAX USING pure CSS selector $('.annotation-link').filter(':hidden').show();

  //Also note that we could see a speed improvement showing/hiding things using
  // .addClass(), .removeClass()  or  .css('display', ''), .css('display', 'none')
  //fast vis test: return !(/none/i.test(element.css('display'))) && !(/hidden/i.test(element.css('visibility')));

  console.log('BOOP: document.ready done');
  // setTimeout(
  //   function() {
  //     console.log('HS: ' + $('#highlight_styles').cssText());
  //   },
  //   2000
  // );
});


