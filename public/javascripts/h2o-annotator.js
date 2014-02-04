var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
__hasProp = {}.hasOwnProperty,
__extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

Annotator.Plugin.H2O = (function() {
H2O.prototype.field = null;

H2O.prototype.input = null;

H2O.prototype.options = {
  categories: {}
};

function H2O(element, categories) {
  this.options.categories = categories;
  this.setAnnotationCat = __bind(this.setAnnotationCat, this);
  this.updateViewer = __bind(this.updateViewer, this);
  this.updateViewerCollageLink = __bind(this.updateViewerCollageLink, this);
}

H2O.prototype.pluginInit = function() {
  var h2o_annotator = this;
  this.annotator.viewer.addField = function(options) {
    var field;
    field = $.extend({
      load: function() {}
    }, options);
    field.element = $('<div />')[0];
    this.fields.unshift(field);
    field.element;
    return this;
  };
  this.annotator.deleteAnnotation = function(annotation) {
    //H2O customization:
    this.publish('beforeAnnotationDeleted', [annotation]);

    var child, h, _k, _len2, _ref1;
    if (annotation.highlights != null) {
      _ref1 = annotation.highlights;
      for (_k = 0, _len2 = _ref1.length; _k < _len2; _k++) {
        h = _ref1[_k];
        if (!(h.parentNode != null)) {
          continue;
        }
        child = h.childNodes[0];
        $(h).replaceWith(h.childNodes);
      }
    }
    this.publish('annotationDeleted', [annotation]);
    return annotation;
  };

  this.annotator.subscribe("annotationEditorShown", function(editor, annotation) {
    if(annotation.id === "noid") {
      $('.return-to-annotation').hide();
      $('.link-to-collage').show();
      $.openCollageLinkForm('collage_links/embedded_pager');
    } else {
      $('.link-to-collage,.return-to-annotation').hide();
    }
  });
  $('.link-to-collage').click(function(e) {
    $('.return-to-annotation').show();
    $('.link-to-collage').hide();
    $('.annotator-listing > li:not(.annotator-collage_links)').slideUp();
    $('.annotator-listing > li.annotator-collage_links').slideDown();
    e.preventDefault();
  });
  $('.return-to-annotation').click(function(e) {
    $('.return-to-annotation').hide();
    $('.link-to-collage').show();
    $('.annotator-listing > li:not(.annotator-collage_links)').slideDown();
    $('.annotator-listing > li.annotator-collage_links').slideUp();
    e.preventDefault();
  });
  this.annotator.subscribe("annotationCreated", function(annotation) {
    H2O.prototype.setHighlights(annotation);
    H2O.prototype.setUnlayeredSingle(annotation);
    H2O.prototype.setLayeredBorders([annotation]);
    jQuery.rehighlight();
    jQuery.updateWordCount();
  });
  this.annotator.subscribe("annotationsLoaded", function(annotations) {
    if(heatmap_display) {
      return;
    }

    H2O.prototype.setLayeredBorders(annotations);
    jQuery.rehighlight();
    jQuery.hideShowUnlayeredOptions();
    jQuery.updateWordCount();
    H2O.prototype.manageLayerCleanup(h2o_annotator.annotator, undefined, false);

    st_annotator = h2o_annotator.annotator;
    recorded_annotations = h2o_annotator.annotations;

    if(h2o_annotator.annotator.options.readOnly) {
      access_results = { 'can_edit_annotations' : false };
    }
    jQuery.loadState($(this).data('collage_id'), $(this).data('original_data'));

    //loadState has to be before listenTo
    if(!h2o_annotator.annotator.options.readOnly) {
      jQuery.listenToRecordCollageState();
    }
    
    H2O.prototype.setUnlayeredListeners();
  });
  this.annotator.subscribe("beforeAnnotationDeleted", function(annotation) {
    if(annotation.id !== 'noid') {
      H2O.prototype.beforeDestroyAnnotationMarkup(annotation);
    }
  });
  this.annotator.subscribe("annotationDeleted", function(annotation) {
    if(annotation.id !== 'noid') {
      H2O.prototype.destroyAnnotationMarkup(annotation);
      H2O.prototype.resetUnlayered();
      H2O.prototype.manageLayerCleanup(h2o_annotator.annotator, annotation, false);
      jQuery.updateWordCount();
    }
  });
  this.annotator.subscribe("annotationUpdated", function(annotation) {
    annotation.new_layer_list = [];
    $.each($('.annotator-h2o_layer'), function(i, el) {
      var input = $(el).find('input[name=new_layer]');
      var hex = $(el).find('.hexes .active');
      if(input.val() != '' && hex.size() > 0) {
        annotation.new_layer_list.push({ layer: input.val(), hex: hex.data('value') });
      } else {
        annotation.error = true;
      }
    });
    $('.annotator-h2o_layer').remove();
    H2O.prototype.updateAnnotationMarkup(annotation);
  });

  var cat, color, _ref;
  _ref = this.options.categories;
  for (cat in _ref) {
    color = _ref[cat];
    this.annotator.editor.addField({
      id: 'layer-' + cat,
      type: 'checkbox',
      label: cat,
      value: cat,
      hl: color,
      checked: false,
      load: this.updateField
    });
  }
  this.annotator.editor.addField({
    id: 'add_new_layer',
    type: 'h2o_layer_button',
    label: 'New Layer',
    submit: this.setAnnotationCat
  });
  this.annotator.editor.addField({
    id: 'collage_links',
    type: 'collage_links',
    label: 'Collage Links'
  });
  this.viewer = this.annotator.viewer.addField({
    load: this.updateViewer
  });
  this.viewer = this.annotator.viewer.addField({
    load: this.updateViewerCollageLink
  });
  if (this.annotator.plugins.Filter) {
    this.annotator.plugins.Filter.addFilter({
      label: 'H2O',
      property: 'category',
      isFiltered: Annotator.Plugin.H2O.filterCallback
    });
  }

  return this.input = $(this.field).find(':input');
};

H2O.prototype.setViewer = function(viewer, annotations) {
  var v;
  return v = viewer;
};

H2O.prototype.afterCollageCreated = function(annotation, data) {
  $('.annotation-noid').addClass('annotation-' + annotation.id).removeClass('annotation-noid').data('layered', annotation.id);
  $('.layered-control-start-noid').removeClass('layered-control-start-noid').addClass('layered-control-start-' + annotation.id).data('layered', annotation.id);
  $('.layered-control-end-noid').removeClass('layered-control-end-noid').addClass('layered-control-end-' + annotation.id).data('layered', annotation.id);
  var categories = annotation.category;
  for(var _i = 0; _i < annotation.new_layer_list.length; _i++) {
    categories.push('layer-' + annotation.new_layer_list[_i].layer); 
  }
  var layer_class = categories.join(' ');
  $('.layered-ellipsis-noid').removeClass('layered-ellipsis-noid').addClass('layered-ellipsis-' + annotation.id + ' ' + $.clean_layer(layer_class)).data('layered', annotation.id);

  if(annotation.linked_collage_id !== null && annotation.linked_collage_id !== undefined && annotation.linked_collage_id != '') {
    linked_collages["c" + annotation.linked_collage_id] = data.linked_collage_name;
    $('.annotation-' + annotation.id).addClass('collage-link');
  }
};

H2O.prototype.manageLayerCleanup = function(_annotator, annotation, check_for_new) {
  if(heatmap_display) {
    return false;
  }

  $.each($('#layers_highlights li'), function(i, el) {
    if($('span.layer-' + $.clean_layer($(el).data('name')) + ':not(.annotator-category *)').size() == 0) {
      var found = false;
      if(check_for_new) {
        $.each(annotation.new_layer_list, function(j, new_layer) {
          if($(el).data('name') == new_layer.layer) {
            found = true;
          }
        });
      }
      if(!found) {
        if($(el).data('name') != 'required') {
          var updated_fields = new Array();
          for(var _j = 0; _j < _annotator.editor.fields.length; _j++) {
            if(_annotator.editor.fields[_j].id != 'layer-' + $(el).data('name')) {
              updated_fields.push(_annotator.editor.fields[_j]);
            }
          }
          _annotator.editor.fields = updated_fields;
      
          $('.annotator-listing li.' + $.clean_layer($(el).data('name'))).remove();
        }
        $("#layers li[data-name='" + $(el).data('name') + "']").remove();
        $(el).remove(); 
      }
    }
  });
};

H2O.prototype.manageNewLayers = function(annotation, data) {
  var _this = this;

  //TODO: If annotation.category includes required, and 
  // #layers li[data-name='required'] is empty
  // Add to highlight and hide in navigation

  if(annotation.new_layer_list !== undefined && annotation.new_layer_list.length > 0) {
    _this.annotator.editor.element.find('.annotator-h2o_layer_button').remove();
    _this.annotator.editor.fields.pop();
    $.each(annotation.new_layer_list, function(i, el) {
      annotation.category.push("layer-" + el.layer);
      layer_data[el.layer] = el.hex;
      _this.annotator.editor.addField({
        id: 'layer-' + el.layer,
        type: 'checkbox',
        label: el.layer,
        value: el.layer,
        hl: el.hex,
        checked: false,
        load: _this.updateField
      });
      $.each(JSON.parse(data.color_map), function(j, cm) {
        if(cm == el.hex) {
          el.id = j;
        }
      });
      
      var new_node = $($.mustache(layer_tools_visibility, el));
      new_node.appendTo($('#layers'));
      var new_node2 = $($.mustache(layer_tools_highlights, el));
      new_node2.appendTo($('#layers_highlights'));
    });
    _this.annotator.editor.addField({
      id: 'add_new_layer',
      type: 'h2o_layer_button',
      label: 'New Layer',
      submit: _this.setAnnotationCat
    });
    annotation.new_layer_list = [];
  }
};

H2O.prototype.updateAnnotationMarkup = function(annotation) {
  var class_string = ''
  $.each($('.highlight_layer'), function(_i, el) {
    class_string += 'layer-' + $(el).data('layer') + ' highlight-' + $(el).data('layer') + ' ';
  });
  $('.annotation-' + annotation.id).removeClass(class_string);
  if(annotation.category !== undefined) {
    for(var _i = 0; _i < annotation.category.length; _i++) {
      $('.annotation-' + annotation.id).addClass(annotation.category[_i]);
      if($(".highlight_layer[data-layer='" + annotation.category[_i].replace('layer-', '') + "']").data('highlight')) {
        $('.annotation-' + annotation.id).addClass(annotation.category[_i].replace('layer-', 'highlight-'));
      }
    }
  }
};

H2O.prototype.destroyAnnotationMarkup = function(annotation) {
  var first_highlight = $('.delete-' + annotation.id + ':first');
  var prev_node = first_highlight.prev('.unlayered-' + first_highlight.data('unlayered'));
  var last_highlight = $('.delete-' + annotation.id + ':last');
  var next_node = last_highlight.next('.unlayered-' + last_highlight.data('unlayered'));
  if($('.delete-' + annotation.id).size() == 1 && prev_node.size() > 0 && next_node.size() > 0) {
    first_highlight.hide();
    next_node.hide();
    prev_node.html(prev_node.html() + first_highlight.html() + next_node.html());
    first_highlight.remove();
    next_node.remove();
  } else {
    if(prev_node.size() > 0) {
      first_highlight.hide();
      prev_node.html(prev_node.html() + first_highlight.html());
      first_highlight.remove();
    } 
    if(next_node.size() > 0) {
      next_node.hide();
      last_highlight.html(last_highlight.html() + next_node.html());
      next_node.remove();
    }
  }
  $('.delete-' + annotation.id).removeClass('delete-' + annotation.id);
};

H2O.prototype.beforeDestroyAnnotationMarkup = function(annotation) {
  $('.layered-control-start-' + annotation.id + ',.layered-ellipsis-' + annotation.id + ',.layered-control-end-' + annotation.id).remove();

  var all_items = $('.unlayered,.annotator-hl');

  if(annotation.highlights === undefined) {
    annotation.highlights = $('.annotation-' + annotation.id); 
  }

  // if annotation.highlight first previous is unlayered
  var front_unlayered = false;
  var first_pos = all_items.index(annotation.highlights[0]);
  var prev_node = $(all_items[first_pos - 1]);
  if(prev_node.is('.unlayered') && $(annotation.highlights[0]).parents('.annotator-hl').size() == 0) {
    front_unlayered = true;
  }
  // if annotation.highlight last next is unlayered
  var back_unlayered = false;
  var last_highlight = annotation.highlights[annotation.highlights.length - 1];
  var last_pos = all_items.index(last_highlight);
  var next_node = $(all_items[last_pos + 1]);
  if($(last_highlight).parents('.annotator-hl').size() == 0 && (last_pos != (all_items.size() - 1)) && (next_node.is('.unlayered'))) {
    back_unlayered = true;
  }

  if(front_unlayered && back_unlayered && ($(annotation.highlights).children('.annotator-hl').size() > 0 || $(annotation.highlights).parents('.annotator-hl').size() > 0)) {
    for(var _i = 0; _i < annotation.highlights.length; _i++) {
      var contents = $(annotation.highlights[_i]).contents();
      for(var _j = 0; _j < contents.length; _j++) {
        var parent_count = $(contents[_j]).parents('.annotator-hl:not(.annotation-' + annotation.id + ')').size();
        if(contents[_j].nodeType == 3 && parent_count == 0) {
          var updated = '<span class="delete-' + annotation.id + ' unlayered">' + $(contents[_j]).text() + '</span>';
            $(contents[_j]).replaceWith(updated); 
          }
        }
      }
    } else if(front_unlayered || back_unlayered) {
      for(var _i = 0; _i < annotation.highlights.length; _i++) {
        if($(annotation.highlights[_i]).parents('.annotator-hl').size() == 0) {
          var contents = $(annotation.highlights[_i]).contents();
          for(var _j = 0; _j < contents.length; _j++) {
            if(contents[_j].nodeType == 3) {
              var updated = '<span class="delete-' + annotation.id + ' unlayered">' + $(contents[_j]).text() + '</span>';
              $(contents[_j]).replaceWith(updated); 
            }
          }
        }
      }
    }
  };

  H2O.prototype.setLayeredBorders = function(annotations) {
    for(var _i=0; _i<annotations.length; _i++) {
      var _id = annotations[_i].id;
      if(_id === undefined) {
        _id = 'noid';
      }
      var layer_class = '';
      if(annotations[_i].category !== undefined) {
        var layer_class = annotations[_i].category.join(' ');
      }
      var start_node = $('.annotation-' + _id + ':first');
      var end_node = $('.annotation-' + _id + ':last');
      $('<a href="#" class="layered-control-start layered-control-start-' + _id + ' ' + $.clean_layer(layer_class) + '" data-layered="' + _id + '"></a>').insertBefore(start_node);
      $('<a href="#" class="layered-ellipsis layered-ellipsis-' + _id + ' ' + $.clean_layer(layer_class) + '" data-layered="' + _id + '">[...]</a>').insertBefore(start_node);
      $('<a href="#" class="layered-control-end layered-control-end-' + _id + ' ' + $.clean_layer(layer_class) + '" data-layered="' + _id + '"></a>').insertAfter(end_node);
    }
    $('.layered-ellipsis').off('click').on('click', function(e) {
      e.preventDefault();
      var _id = $(this).data('layered');
      $('.annotation-' + _id).show();
      $('.annotation-' + _id).parents('.original_content').show();
      $('.layered-control-start-' + _id + ',.layered-control-end-' + _id).css('display', 'inline-block');
      $(this).hide();
    });
    $('.layered-control-start,.layered-control-end').off('click').on('click', function(e) {
      e.preventDefault();
      var _id = $(this).data('layered');
      $('.annotation-' + _id).hide();
      $('.layered-control-start-' + _id + ',.layered-control-end-' + _id).hide();
      $('.layered-ellipsis-' + _id).css('display', 'inline-block');
      $('.annotation-' + _id).parents('.original_content').filter(':not(.original_content *):not(:has(.unlayered:visible,.annotator-hl:visible,.layered-ellipsis:visible))').hide();
    });
  };

  H2O.prototype.resetUnlayered = function() {
    //resetting parents that have no annotator children to unlayered, and resetting unlayered children inside
    var collage_selector = $('#collage' + collage_id);
    $.each(collage_selector.find('.annotator-wrapper .original_content:not(.annotator-hl,.unlayered *, .unlayered,:has(.annotator-hl),br)'), function(i, el) {
      $(el).addClass('unlayered');
      $.each($(el).find('.unlayered'), function(j, unlayered_el) {
        $(unlayered_el).contents().unwrap();
      });
      $(el).find('.unlayered-control-start,.unlayered-control-end,.unlayered-ellipsis').remove();
    });

    //removing any unlayered control borders, ellipsis for not needed anymore
    var all_items = $('.unlayered-control-start,.unlayered-control-end,.unlayered:not(:has(.unlayered)),.annotator-hl');
    for(var _i = 1; _i < all_items.size() - 1; _i++) {
      var _this = $(all_items[_i]);
      var _next = $(all_items[_i + 1]);
      var _prev = $(all_items[_i - 1]);
      if(_this.is('.unlayered-control-end') && (!_prev.is('.unlayered') || (_prev.is('.unlayered') && _next.is('.unlayered')))) {
        _this.remove();
      }
      if(_this.is('.unlayered-control-start') && (!_next.is('.unlayered') || (_prev.is('.unlayered') && _next.is('.unlayered')))) {
        _this.next('.unlayered-ellipsis').remove();
        _this.remove();
      }
    }

    all_items = $('.unlayered:not(:has(.unlayered)),.annotator-hl');
    var unlayered = 0;

    if(all_items.first().is('.unlayered')) {
      var _this = all_items.first();
      if(!_this.prev().is('.unlayered-ellipsis')) {
        $('.unlayered-control-first,.unlayered-ellipsis-first').remove();
        $('<a href="#" class="unlayered-control-start unlayered-control-first unlayered-control-start-' + unlayered + '" data-unlayered="' + unlayered + '"></a>').insertBefore(_this);
        $('<a href="#" class="unlayered-ellipsis unlayered-ellipsis-first unlayered-ellipsis-' + unlayered + '" data-unlayered="' + unlayered + '">[...]</a>').insertBefore(_this);
      } else {
        _this.prev().removeClass('unlayered-ellipsis-' + _this.prev().data('unlayered')).addClass('unlayered-ellipsis-' + unlayered).data('unlayered', unlayered);
        _this.prev().prev().removeClass('unlayered-control-start-' + _this.prev().prev().data('unlayered')).addClass('unlayered-control-start-' + unlayered).data('unlayered', unlayered);
      }
    } else {
      $('.unlayered-control-first,.unlayered-ellipsis-first').remove();
    }

    for(var _i = 0; _i < all_items.size() - 1; _i++) {
      var _this = $(all_items[_i]);
      var _next = $(all_items[_i + 1]);
      if(_this.is('.unlayered') && _next.is('.annotator-hl')) {
        if(!_this.next().is('.unlayered-control-end')) {
          $('<a href="#" class="unlayered-control-end unlayered-control-end-' + unlayered + '" data-unlayered="' + unlayered + '"></a>').insertAfter(_this);
        } else {
          _this.next().removeClass('unlayered-control-end-' + _this.next().data('unlayered')).addClass('unlayered-control-end-' + unlayered).data('unlayered', unlayered);
        }
      }
      if(_this.is('.annotator-hl') && _next.is('.unlayered')) {
        unlayered = unlayered + 1;
        if(!_next.prev().is('.unlayered-ellipsis')) {
          $('<a href="#" class="unlayered-control-start unlayered-control-start-' + unlayered + '" data-unlayered="' + unlayered + '"></a>').insertBefore(_next);
          $('<a href="#" class="unlayered-ellipsis unlayered-ellipsis-' + unlayered + '" data-unlayered="' + unlayered + '">[...]</a>').insertBefore(_next);
        } else {
          _next.prev().removeClass('unlayered-ellipsis-' + _next.prev().data('unlayered')).addClass('unlayered-ellipsis-' + unlayered).data('unlayered', unlayered);
          _next.prev().prev().removeClass('unlayered-control-start-' + _next.prev().prev().data('unlayered')).addClass('unlayered-control-start-' + unlayered).data('unlayered', unlayered);
        }
      }
      if(_this.is('.unlayered')) {
        _this.removeClass('unlayered-' + _this.data('unlayered')).addClass('unlayered-' + unlayered).data('unlayered', unlayered); 
      }
    }

    if(all_items.last().is('.unlayered')) {
      var _this = all_items.last();
      _this.removeClass('unlayered-' + _this.data('unlayered')).addClass('unlayered-' + unlayered).data('unlayered', unlayered); 
      if(!_this.next().is('.unlayered-control-end')) {
        $('.unlayered-control-last').remove();
        $('<a href="#" class="unlayered-control-end unlayered-control-last unlayered-control-end-' + unlayered + '" data-unlayered="' + unlayered + '"></a>').insertAfter(_this);
      } else {
        _this.next().removeClass('unlayered-control-end-' + _this.next().data('unlayered')).addClass('unlayered-control-end-' + unlayered).data('unlayered', unlayered);
      }
    } else {
      $('.unlayered-control-last').remove();
    }

  };

  H2O.prototype.setUnlayeredSingle = function(annotation) {
    $.each(annotation.highlights, function(_i, el) {
      if($(el).parents('.annotator-hl').size() == 0) {
        var parent_node = $(el).parent();
        var contents = $(parent_node).contents();
	      for(var _j = 0; _j < contents.length; _j++) {
	        if(contents[_j].nodeType == 3) {
	          var filtered = $(contents[_j]).text().replace(/\s+/, '');
	          if(filtered != '') {
	            var updated = '<span class="unlayered">' + $(contents[_j]).text() + '</span>';
	            $(contents[_j]).replaceWith(updated);
	          }
	        }
	      }
	      if(parent_node.is('span.unlayered')) {
	        parent_node.contents().unwrap();
	      } else {
	        var unlayered_parents = $(el).parents('.unlayered');
	        var unlayered = unlayered_parents.first().data('unlayered');
	        unlayered_parents.removeClass('unlayered unlayered-' + unlayered);
	      }
      }
    });
 
    this.resetUnlayered();
  };

  H2O.prototype.setAllUnlayered = function() {
    var collage_selector = $('#collage' + collage_id);

    $('div.article *:not(.paragraph-numbering)').addClass('original_content');
    collage_selector.find('.annotator-wrapper .original_content:not(.annotator-hl,:has(.annotator-hl),br)').addClass('unlayered');
    collage_selector.find('.unlayered .unlayered').removeClass('unlayered');

    $.each(collage_selector.find('.annotator-wrapper .original_content:not(.unlayered, .unlayered *)'), function(i, el) {
	    var contents = $(el).contents();
	    for(var _i = 0; _i < contents.length; _i++) {
	      if(contents[_i].nodeType == 3) {
	        var filtered = $(contents[_i]).text().replace(/\s+/, '');
	        if(filtered == '') {
	          $(contents[_i]).remove();
	        } else {
	          var updated = '<span class="unlayered">' + $(contents[_i]).text() + '</span>';
	          $(contents[_i]).replaceWith(updated); 
	        }
	      }
	    }
    });

    $('.annotator-wrapper,.annotator-outer,.annotator-outer *,.annotator-adder,.annotator-adder *').removeClass('unlayered original_content');

    this.resetUnlayered();
  };

  H2O.prototype.setUnlayeredListeners = function() {
    $(document).delegate('.unlayered-ellipsis', 'click', function(e) {
      e.preventDefault();
      var key = $(this).data('unlayered');
      $('.unlayered-' + key).show();
      $('.unlayered-control-start-' + key + ',.unlayered-control-end-' + key).css('display', 'inline-block');
      $(this).hide();
      jQuery.hideShowUnlayeredOptions();
    });
    $(document).delegate('.unlayered-control-start,.unlayered-control-end', 'click', function(e) {
      e.preventDefault();
      var key = $(this).data('unlayered');
      $('.unlayered-' + key).hide();
      $('.unlayered-ellipsis-' + key).show();
      $('.unlayered-control-start-' + key + ',.unlayered-control-end-' + key).hide();
      jQuery.hideShowUnlayeredOptions();
    });
  };

  H2O.prototype.setHighlights = function(annotation) {
    var h, highlights, _i, _len, _results;
    highlights = annotation.highlights;
    _results = [];
    for (_i = 0; _i < highlights.length; _i++) {
      h = highlights[_i];
      _results.push(h.className = h.className + ' annotation-noid');
      for(_c = 0; _c < annotation.category.length; _c++) {
        _results.push(h.className = h.className + ' ' + annotation.category[_c]);
        var _l = annotation.category[_c].replace(/^layer-/, '');
        if($("#layers_highlights li[data-name='" + _l + "']").size() &&
          $("#layers_highlights li[data-name='" + _l + "'] a").html().match(/^UNHIGHLIGHT/)) {
          _results.push(h.className = h.className + ' highlight-' + _l);
        }
      }
      for(_c = 0; _c < annotation.new_layer_list.length; _c++) {
        _results.push(h.className = h.className + ' layer-' + annotation.new_layer_list[_c].layer);
      }
      $.each($('a.highlight_layer'), function(_i, el) {
        if($(el).data('highlight') && h.className.match('layer-' + $(el).data('layer'))) {
          _results.push(h.className = h.className + ' highlight-' + $(el).data('layer'));
        }
      });
    }
    return _results;
  };

  H2O.prototype.updateField = function(field, annotation) {
    if(annotation.id == 'noid' && heatmap_display) {
      $('#heatmap_toggle.disabled').click();
    }
    if(annotation.category !== undefined && $.inArray(field.childNodes[0].id, annotation.category) != -1) {
      $(field).find('input').attr('checked', true);
    } else {
      $(field).find('input').attr('checked', false);
    }
    return true;
  };

  H2O.prototype.setAnnotationCat = function(field, annotation) {
    annotation.category = [];
    $.each(this.annotator.editor.fields, function(_i, _field) {
      if($('.annotator-listing li.' + $.clean_layer(_field.id) + ' input').attr('checked') == 'checked') {
        annotation.category.push(_field.id);
      }
    });
    return;
  };

  H2O.prototype.updateViewerCollageLink = function(field, annotation) {
    if($('#print-options').size() > 0 || heatmap_display) {
      return;
    }

    field = $(field);
    field.addClass('annotator-collage').hide();
    if(annotation.linked_collage_id !== null && annotation.linked_collage_id !== undefined && annotation.linked_collage_id != '') {
      field.show();
      field.append($('<span>Linked Collage: <a target="_blank" href="/collages/' + annotation.linked_collage_id + '">' + linked_collages["c" + annotation.linked_collage_id] + '</a></span>'));
    }
  }

  H2O.prototype.updateViewer = function(field, annotation) {
    if($('#print-options').size() > 0) {
      return;
    }
    if(heatmap_display) {
      $('.annotator-controls').css('visibility', 'hidden');
    } else {
      $('.annotator-controls').css('visibility', 'visible');
    }
    if(annotation.linked_collage_id !== null && annotation.linked_collage_id !== undefined && annotation.linked_collage_id != '') {
      $('.annotator-edit').css('visibility', 'hidden');
    } else {
      $('.annotator-edit').css('visibility', 'visible');
    }

    field = $(field);
    field.addClass('annotator-category');
    // TODO: Figure out why new annotations have layers listed twice, but for 
    // now, this handles the symptom
    var displayed = {};
    if(heatmap_display) {
      if(annotation.collage_id == $.getItemId()) {
        field.append($('<h3>Current Collage</h3>'));
      } else {
        field.append($('<h3><a href="/collages/' + annotation.collage_id + '">Collage ' + annotation.collage_id + '</h3>'));
      }
    }
    if(annotation.category !== undefined && annotation.category.length > 0) {
	    for(_c = 0; _c < annotation.category.length; _c++) {
        var layer = annotation.category[_c];
        var clean_layer = $.clean_layer(layer);
	      var layer_name = annotation.category[_c].replace(/layer-/, '');
	      if(field.find('span.' + clean_layer).size() == 0) {
          if(annotation.collage_id == $.getItemId()) {
	          var hex = layer_data[layer.replace(/layer-/, '')];
	          var color_combine = jQuery.xcolor.opacity('#FFFFFF', hex, 0.4);
	          field.append($('<span>').attr('style', 'background-color:' + color_combine.getHex()).html(layer_name).addClass('layer-' + clean_layer));
          } else {
	          field.append($('<span>').html(layer_name).addClass('layer-' + clean_layer));
          }
	        displayed[layer_name] = 1;
	      }
	    }
    } else {
      field.hide();
    }
  };

  H2O.prototype.loadAnnotations = function() {
    var annotation_data = [];
    $.each(annotations, function(i, el) {
      var annotation = JSON.parse(el).annotation;
      var ranges = [{
            "start": annotation.xpath_start,
            "end": annotation.xpath_end,
            "startOffset": annotation.start_offset,
            "endOffset": annotation.end_offset
      }];
      var category = new Array();
      for(var _j = 0; _j < annotation.layers.length; _j++) {
        category.push('layer-' + annotation.layers[_j].name);
      }
      var formatted_annotation = { "id" : annotation.id,
        "text" : annotation.annotation,
        "ranges": ranges,
        "category": category,
        "cloned": annotation.cloned,
        "collage_id" : annotation.collage_id,
        "linked_collage_id" : annotation.linked_collage_id
      };
      formatted_annotation.ranges = ranges;
      annotation_data.push(formatted_annotation);
    });
    return this.annotator.plugins.Store._onLoadAnnotations(annotation_data);
  }
  
  H2O.prototype.specialDeleteAnnotation = function(annotation) {
    var _this = this;
    var _annotator = _this.annotator;

    _annotator.publish('beforeAnnotationDeleted', [annotation]);
    var child, h, _k, _len2, _ref1;
    if (annotation.highlights != null) {
      _ref1 = annotation.highlights;
      for (_k = 0, _len2 = _ref1.length; _k < _len2; _k++) {
        h = _ref1[_k];
        if (!(h.parentNode != null)) {
          continue;
        }
        child = h.childNodes[0];
        $(h).replaceWith(h.childNodes);
      }
    }
    _this.destroyAnnotationMarkup(annotation);
    _this.manageLayerCleanup(_this, annotation, false);
    _annotator.plugins.Store.annotations.splice(_annotator.plugins.Store.annotations.indexOf(annotation), 1);

    return;
  };

  return H2O;

})();
