var all_tts;
var stored_heatmap = {};
var loaded_heatmaps = false;
var annotations;
var original_data = {};
var layer_data;
var collage_id;
var heatmap_display = false;
//var last_data;

$.extend({
  clean_layer: function(layer_name) {
    return layer_name.replace(/\./, 'specialsymbol');
  },
  rehighlight: function() {
    //do nothing
  },
  hideShowUnlayeredOptions: function() {
    //do nothing
  },
  updateWordCount: function() {
    //do nothing
  },
  loadState: function(collage_id, data) {
    $.each(data, function(i, e) {
		    if(i.match(/^unlayered/)) {
		      $('#collage' + collage_id + ' .unlayered-' + e).remove();
		      $('#collage' + collage_id + ' .unlayered-ellipsis-' + e).replaceWith($('<span>').addClass('unlayered-ellipsis').html('[...]').show());
		    } else if(i.match(/^layered/)) {
		      $('#collage' + collage_id + ' .annotation-' + e).remove();
		      $('#collage' + collage_id + ' .layered-ellipsis-' + e).replaceWith($('<span>').addClass('layered-ellipsis').html('[...]').show());
      } else if(i == 'font_face') {
        $('#fontface').val(e);
      } else if(i == 'font_size') {
        $('#fontsize').val(e);
      } else if(i == 'highlights') {
        $('#printhighlights').val('original');
        $('#printheatmap').val('no');
        export_functions.version2.highlightCollage(collage_id, e);
      }
      if(i == 'load_heatmap') {
        export_functions.version2.displayHeatmap(collage_id);
        $('#printheatmap').val('yes');
        $('#printhighlights option:first').remove();
        $('#printhighlights').val('none');
      }
    });
    $('#collage' + collage_id + ' .unlayered-ellipsis:not(:visible),#collage' + collage_id + ' .layered-ellipsis:not(:visible)').remove();

    $.each(['a', 'em', 'sup', 'p', 'center', 'h2', 'pre'], function(i, selector) {
      var set = $('#collage' + collage_id + ' div.article ' + selector);
      set = set.filter(':not(:has(*:visible)):not(.paragraph-numbering)');
      set.remove();
    });
    
    var cannotations = eval("annotations_" + collage_id);
    $.each(cannotations, function(i, ann) {
      var annotation = $.parseJSON(ann).annotation;
      $('<span>').addClass('annotation-content annotation-content-' + annotation.id).html(annotation.annotation).insertAfter($('.annotation-' + annotation.id + ':last'));
    });
  }
});

var export_functions = {
  init: function() {
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
	  $('#printannotations').val('no').selectbox({
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
	  $('#printfontdetails').selectbox({
	    className: "jsb", replaceInvisible: true
	  }).change(function() {
	    var choice = $(this).val();
	    if (choice == 'yes') {
	      $('.fontdetails').show();
	    }
	    else {
	      $('.fontdetails').hide();
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
	  $('#printhighlights').selectbox({
	    className: "jsb", replaceInvisible: true
	  }).change(function() {
	    var choice = $(this).val();
      $('#highlight_styles').text('');
	    if($('#printheatmap').val() == 'yes') {
        heatmap_display = false;
	      $('#printheatmap').val('no');
	      $('#heatmap_options .jsb-currentItem').html('No');
	    }
	    if(choice == 'original') {
	      $('.collage-content').each(function(i, el) {
	        var id = $(el).data('id');
	        var data = eval("collage_data_" + id);
	        export_functions["version" + $(el).data('annotator_version')].highlightCollage(id, data.highlights);
	      });
	    } else if(choice == 'all') {
	      $('.collage-content').each(function(i, el) {
	        var id = $(el).data('id');
          if($(el).data('annotator_version') == 1) {
	          export_functions.version1.highlightCollage(id, eval("color_map_" + id));
          } else {
	          export_functions.version2.highlightCollage(id, eval("layer_data_" + id));
          }
	      });
	    } else {
	      $('.collage-content').each(function(i, el) {
	        var id = $(el).data('id');
          if($(el).data('annotator_version') == 2) {
            //clear highlight class
	          export_functions.version2.highlightCollage(id, {});
          }
	      });
	    }
	  });
	  $('#printheatmap').selectbox({
	    className: "jsb", replaceInvisible: true 
	  }).change(function() {
	    var choice = $(this).val();
	    if($('#printhighlights').val() == 'original' || $('#printhighlights').val() == 'all') {
	      $('#printhighlights').val('none');
	      $('#highlight_options .jsb-currentItem').html('None');
	    }
	    if(choice == 'yes') {
        heatmap_display = true;
	      $('.collage-content').each(function(i, el) {
	        var id = $(el).data('id');
          export_functions["version" + $(el).data('annotator_version')].displayHeatmap(id);
	      });
	    } else {
        heatmap_display = false;
        $('#highlight_styles').text('');
	    }
	  });

	  if(document.location.hash.match('fontface')) {
	    var vals = document.location.hash.replace('#', '').split('-');
	    for(var i in vals) {
	      var font_values = vals[i].split('=');
	      if(font_values[0] == 'fontsize' || font_values[0] == 'fontface') {
	        $('#' + font_values[0]).val(font_values[1]);
	      }
	    }
	  }
	  export_functions.setFontPrint();
  },
  setFontPrint: function() {
    var font_size = $('#fontsize').val();
    var font_face = $('#fontface').val();
    var base_font_size = base_font_sizes[font_face][font_size];
    if(font_face == 'verdana') {
      $.rule("body .singleitem *, body .singleitem article tt { font-family: Verdana, Arial, Helvetica, Sans-serif; font-size: " + base_font_size + 'px; }').appendTo('#additional_styles');
    } else {
      $.rule("body .singleitem *, body .singleitem article tt { font-family: '" + font_map[font_face] + "'; font-size: " + base_font_size + 'px; }').appendTo('#additional_styles');
    }
    $.rule('.singleitem *.scale1-5 { font-size: ' + base_font_size*1.5 + 'px; }').appendTo('#additional_styles');
    $.rule('.singleitem *.scale1-4 { font-size: ' + base_font_size*1.4 + 'px; }').appendTo('#additional_styles');
    $.rule('.singleitem *.scale1-3 { font-size: ' + base_font_size*1.3 + 'px; }').appendTo('#additional_styles');
    $.rule('.singleitem *.scale1-2 { font-size: ' + base_font_size*1.2 + 'px; }').appendTo('#additional_styles');
    $.rule('.singleitem *.scale1-1 { font-size: ' + base_font_size*1.1 + 'px; }').appendTo('#additional_styles');
    $.rule('.singleitem *.scale0-9 { font-size: ' + base_font_size*0.9 + 'px; }').appendTo('#additional_styles');
    $.rule('.singleitem *.scale0-8 { font-size: ' + base_font_size*0.8 + 'px; }').appendTo('#additional_styles');
  },
  "version2" : {
	  displayHeatmap: function(id) {
      if($('#collage' + id).data('heatmap_marked_up') === undefined) {
        collage_id = id;
        annotations = eval('heatmap_' + id);
        $('#collage' + id).data('heatmap_marked_up', true);
        st_annotator.plugins.H2O.loadAnnotations();
      }
      var max_layers = 0;
      $.each($('#collage' + id + ' .annotator-hl'), function(i, el) {
        if($(el).parents('.annotator-hl').size() > max_layers) {
          max_layers = $(el).parents('.annotator-hl').size();
        }
      });
      var selector = '#collage' + id + ' .annotator-wrapper';
      for(var i = 0; i <= max_layers; i++) {
        var color_combine = $.xcolor.opacity('#FFFFFF', '#FE2A2A', (i+1)/(max_layers + 1));
        selector += ' .annotator-hl';
        $.rule(selector + ' { border-bottom: 2px solid ' + color_combine.getHex() + ' }').appendTo('#highlight_styles');
      }
	  },
	  loadState: function(id) {
      collage_id = id;
      annotations = eval("annotations_" + id);
      $('#collage' + id + ' div.article').data('collage_id', id).data('original_data', eval("collage_data_" + id)).annotator({ readOnly: true }).annotator('addPlugin', 'H2O', {}).annotator('addPlugin', 'Store', {
        prefix: '/annotations',
        urls: {
          create: '/create',
          read: '/annotations/:id',
          update: '/:id',
          destroy: '/:id',
          search: '/search'
        }
      });
      $('#collage' + id + ' .unlayered-border-start,#collage' + id + ' .unlayered-border-end,#collage' + id + ' .layered-border-start,#collage' + id + ' .layered-border-end').remove();
	  },
	  highlightCollage: function(collage_id, highlights) {
      layer_data = eval("layer_data_" + collage_id);

      var keys = new Array();
      $.each(highlights, function(i, j) {
        keys.push(i);
      });
      $.each(layer_data, function(i, j) {
        if($.inArray(i, keys) == -1) {
          $('#collage' + collage_id + ' .layer-' + i).removeClass('highlight-' + i);
        }
      });
      $.each(highlights, function(i, j) {
        $('#collage' + collage_id + ' .collage-' + collage_id + '.layer-' + i).addClass('highlight-' + i);
      });
	    $('#collage' + collage_id + ' .layered-empty').removeClass('layered-empty');

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
		      var opacity = 0.4 / key_length;
		      $.each(unique_layers, function(key, value) {
		        var color_combine = $.xcolor.opacity(current_hex, layer_data[key], opacity);
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
	    if(keys_arr.length > 0) {
		    $('#collage' + collage_id + ' .annotator-hl:not(' + keys_arr.join(',') + ')').addClass('layered-empty');
	    } else {
	      $('#collage' + collage_id + ' .annotator-hl').addClass('layered-empty');
	    }
	
	  }
  },
  "version1": {
	  printMarkupAnnotation: function(annotation) {
	    var annotation_start = parseInt(annotation.annotation_start.replace(/^t/, ''));
	    var annotation_end = parseInt(annotation.annotation_end.replace(/^t/, ''));
	    var els = all_tts.slice(annotation_start - 1, annotation_end);

	    els.addClass('a a' + annotation.id);
	    $.each(annotation.layers, function(i, layer) {
	      els.addClass('l' + layer.id);
	    });
	
	    if(annotation.annotation != '') {
	      $('<span id="annotation-content-' + annotation.id + '" class="annotation-content">' + annotation.annotation + '</span>').insertAfter(els.last());
	    }
	  },
	  displayHeatmap: function(collage_id) {
      var heatmap = eval('heatmap_' + collage_id);
	    $.each(heatmap.data, function(i, e) {
	      var opacity = e / (heatmap.max + 1);
	      var color_combine = $.xcolor.opacity('#FFFFFF', '#FE2A2A', opacity);
        $.rule('#collage' + collage_id + ' tt#' + i + ' { border-bottom: 2px solid ' + color_combine.getHex() + ' }').appendTo('#highlight_styles');
	    });
	  },
	  loadState: function(id) {
      var annotations = eval("annotations_" + id);
      all_tts = $('#collage' + id + ' div.article tt');
      $.each(annotations, function(i, el) {
        export_functions.version1.printMarkupAnnotation($.parseJSON(el).annotation);
      });
      var data = eval("collage_data_" + id);

      $.each(data, function(i, e) {
        if(i == 'load_heatmap') {
          export_functions.version1.displayHeatmap(id);
          $('#printheatmap').val('yes');
          $('#printhighlights option:first').remove();
          $('#printhighlights').val('none');
        } else if(i == 'highlights') {
          $('#printhighlights').val('original');
          $('#printheatmap').val('no');
          export_functions.version1.highlightCollage(id, e);
        } else if(i == 'font_face') {
          $('#fontface').val(e);
        } else if(i == 'font_size') {
          $('#fontsize').val(e);
        } else if(i.match(/#unlayered-ellipsis/)) {
          var pos_id = parseInt(i.replace(/#unlayered-ellipsis-/, '')) - 1;
          var elements = all_tts.slice(pos_id);
          var next_highlighted = elements.filter('.a:first');
          var unlayered_elements;
          if(next_highlighted.size()) {
            unlayered_elements = elements.slice(0, next_highlighted.data('id') - pos_id - 1);
          } else {
            unlayered_elements = elements;
          }
          $('<span class="ellipsis">[...] </span>').insertBefore(unlayered_elements.first());
          unlayered_elements.hide();
        } else if(i.match(/#annotation-ellipsis/) && e != 'none') {
          var annotation_id = i.replace(/#annotation-ellipsis-/, '');
          var elements = $('tt.a' + annotation_id);
          $('<span class="ellipsis">[...] </span>').insertBefore(elements.first());
          elements.hide();
        } else if(i.match(/#annotation-content/) && e == 'inline-block') {
          //do nothing now with annotator upgrade
        }
      });

      $.each(['a', 'em', 'sup', 'p', 'center', 'h2', 'pre'], function(i, selector) {
        var set = $('#collage' + id + ' article ' + selector);
        set = set.filter(':not(:has(tt:visible))');
        set = set.filter(':not(:has(.ellipsis:visible))');
        set = set.filter(':not(.paragraph-numbering)');
        set.addClass('no_visible_children');
      });

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
	  highlightCollage: function(collage_id, highlights) {
	    $.each(highlights, function(a, hex) {
	      $.each($('#collage' + collage_id + ' tt.' + a), function(i, el) {
	        var current = $(el);
	        var highlight_colors = current.data('highlight_colors');
	        if(highlight_colors) {
	          highlight_colors.push(hex);
	        } else {
	          highlight_colors = new Array(hex);
	        }
	        var current_hex = '#FFFFFF';
	        var opacity = 0.6 / highlight_colors.length;
	        $.each(highlight_colors, function(i, color) {
	          var color_combine = $.xcolor.opacity(current_hex, color, opacity);
	          current_hex = color_combine.getHex();
	        });
          $.rule('#collage' + collage_id + ' tt#' + $(el).attr('id') + ' { border-bottom: 2px solid ' + current_hex + ';}').appendTo('#highlight_styles');
	        current.data('highlight_colors', highlight_colors);
	      });
	    });
	  }
  }
};

$(document).ready(function(){
  if($('#playlist').size()) {
    $('#printhighlights option:first').remove();
    $('#printhighlights').val('none');
    $('#printheatmap').val('no');
  }

  $('.collage-content').each(function(i, el) {
    export_functions["version" + $(el).data('annotator_version')].loadState($(el).data('id')); 
  });

  export_functions.init();
});
