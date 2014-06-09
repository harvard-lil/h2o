!function(e){if("object"==typeof exports)module.exports=e();else if("function"==typeof define&&define.amd)define(e);else{var n;"undefined"!=typeof window?n=window:"undefined"!=typeof global?n=global:"undefined"!=typeof self&&(n=self);var o=n;o=o.Annotator||(o.Annotator={}),o=o.Plugin||(o.Plugin={}),o.H2O=e()}}(function(){var define,module,exports;return (function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);throw new Error("Cannot find module '"+o+"'")}var f=n[o]={exports:{}};t[o][0].call(f.exports,function(e){var n=t[o][1][e];return s(n?n:e)},f,f.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({"apYPS1":[function(_dereq_,module,exports){
(function (global){
var Annotator, self, _ref;

if (typeof self !== "undefined" && self !== null) {
  self = self;
}

if (typeof global !== "undefined" && global !== null) {
  if (self == null) {
    self = global;
  }
}

if (typeof window !== "undefined" && window !== null) {
  if (self == null) {
    self = window;
  }
}

Annotator = self != null ? self.Annotator : void 0;

if (Annotator == null) {
  Annotator = (self != null ? (_ref = self.define) != null ? _ref.amd : void 0 : void 0) ? self != null ? self.require('annotator') : void 0 : void 0;
}

if (typeof Annotator !== 'function') {
  throw new Error("Could not find Annotator! In a webpage context, please ensure that the Annotator script tag is loaded before any plugins.");
}

module.exports = Annotator;


}).call(this,typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {})
},{}],"annotator":[function(_dereq_,module,exports){
module.exports=_dereq_('apYPS1');
},{}],3:[function(_dereq_,module,exports){
var $, Annotator, H2O,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

Annotator = _dereq_('annotator');

$ = Annotator.Util.$;

H2O = (function() {
  function H2O(categories) {
    this.categories = categories;
    this.formatted_annotations = {};
    this.annotation_deleted_id = null;
    this.initialized = false;
    this.collage_id = 0;
    this.updateViewer = __bind(this.updateViewer, this);
    this.updateEditor = __bind(this.updateEditor, this);
  }

  H2O.prototype.field = null;

  H2O.prototype.input = null;

  H2O.prototype.pluginInit = function() {
    this.annotator.subscribe("annotationsLoaded", function(annotations) {
      $.each(annotations, function(i, annotation) {
        $(annotation._local.highlights).addClass('annotation-' + annotation.id);
      });

      if(this.initialized) {
        return;
      }

      this.initialized = true;

      $.each(annotations, function(i, annotation) {
        H2O.prototype.setHighlights(annotation);
        H2O.prototype.setUnlayeredSingle(annotation);
        H2O.prototype.addAnnotationIndicator(annotation);
      });

      H2O.prototype.resetUnlayered(this.plugins.H2O.collage_id);

      H2O.prototype.setLayeredBorders(annotations);
      collages.rehighlight();
      collages.hideShowUnlayeredOptions();
      collages.updateWordCount();

      if(h2o_annotator.options.readOnly) {
        access_results = { 'can_edit_annotations' : false };
      }

      if($('#collage_print').size() > 0) {
        collages.loadState($('.singleitem').data('itemid'), original_data);
      }

      if($('#print-options').size() > 0) {
        var collage_data = eval('collage_data_' + this.plugins.H2O.collage_id);
        collages.loadState(this.plugins.H2O.collage_id, collage_data);
      }
  
      //loadState has to be before listenTo
      if(!h2o_annotator.options.readOnly) {
        collages.listenToRecordCollageState();
      }

      /* UI mods for linked collage */
      $('#linked_collage_id').parent().addClass('collage-linking');
      $('#linked_collage_id').hide();
      $('<div id="collage_search"></div>').hide().insertAfter($('#linked_collage_id'));
      $('<div id="collage_search_buttons"><input id="collage_search_input" /><a href="#" id="collage_search_search">Search</a><a href="#" id="cancel_link_to_collage">Cancel &raquo;</a>').hide().insertAfter($('#linked_collage_id'));
      $('<a>').attr('id', 'link_to_collage').html('Link to Collage').insertAfter($('#linked_collage_id'));
      $('<div id="existing_collage_link"><span></span><a href="#" id="edit_link_to_collage">Edit</a><a href="#" id="delete_link_to_collage">Delete</a></div>').hide().insertAfter($('#link_to_collage'));

      $('<a>').attr('id', 'add_new_layer').html('Add New Layer').insertAfter($('#add_new_layer_placeholder'));
      $('#add_new_layer_placeholder').hide();
    });

    this.annotator.subscribe("annotationEditorSubmit", function(editor) {
      editor.annotation.linked_collage_id = $('#linked_collage_id').val();

      $.each($('.annotator-editor li.annotator-checkbox input'), function(_i, el) {
        if($(el).is(':checked')) {
          var layer_name = $(el).attr('id').replace(/^layer-/, '');
          editor.annotation.layer_hexes.push({ layer: layer_name, hex: h2o_annotator.plugins.H2O.layer_map[layer_name], is_new: false });
        }
      });

      $.each($('input[name=new_layer]'), function(i, el) {
        var hex = $(el).siblings('.hexes').find('.active');
        if($(el).val() != '' && $(el).val() != 'Enter Layer Name' && hex.size() > 0) {
          editor.annotation.layer_hexes.push({ layer: $(el).val().toLowerCase(), hex: hex.text(), is_new: true });
          h2o_annotator.plugins.H2O.layer_map[$(el).val().toLowerCase()] = hex.text();
        }
      });

      $('#add_new_layer').siblings('div').remove();
    });

    this.annotator.subscribe("beforeAnnotationCreated", function(annotation) {
      annotation.layer_hexes = [];
      $('#existing_collage_link,#cancel_link_to_collage').hide();
      $('#link_to_collage').show();
      collages.openCollageLinkForm('/collages/' + h2o_global.getItemId() + '/collage_links/embedded_pager');
    });
    this.annotator.subscribe("beforeAnnotationUpdated", function(annotation) {
      annotation.layer_hexes = [];
      collages.openCollageLinkForm('/collages/' + h2o_global.getItemId() + '/collage_links/embedded_pager');
    });
    this.annotator.subscribe("annotationCreated", function(annotation) {
      annotation.layers = $.parseJSON(annotation.layers);
      annotation.linked_collage_name = annotation.linked_collage_name;
      annotation.linked_collage_id = annotation.linked_collage_id;
      annotation.text = annotation.text;
      $(annotation._local.highlights).addClass('annotation-' + annotation.id);
      linked_collages["c" + annotation.linked_collage_id] = annotation.linked_collage_name;
      H2O.prototype.manageLayers(annotation, 'created');
      H2O.prototype.setHighlights(annotation);
      H2O.prototype.setUnlayeredSingle(annotation);
      H2O.prototype.resetUnlayered(h2o_global.getItemId());
      H2O.prototype.setLayeredBorders([annotation]);
      collages.rehighlight();
      collages.updateWordCount();
      H2O.prototype.addAnnotationIndicator(annotation);
    });
    this.annotator.subscribe("annotationUpdated", function(annotation) {
      annotation.layers = $.parseJSON(annotation.layers);
      annotation.linked_collage_name = annotation.linked_collage_name;
      annotation.linked_collage_id = annotation.linked_collage_id;
      linked_collages["c" + annotation.linked_collage_id] = annotation.linked_collage_name;
      H2O.prototype.manageLayers(annotation, 'updated');
      H2O.prototype.updateAnnotationMarkup(annotation);
      collages.rehighlight();
    });

    this.annotator.subscribe("beforeAnnotationDeleted", function(annotation) {
      if(annotation.id !== undefined) {
        H2O.prototype.beforeDestroyAnnotationMarkup(annotation);
        this.annotation_deleted_id = annotation.id;
      }
    });
    this.annotator.subscribe("annotationDeleted", function(annotation) {
      if(this.annotation_deleted_id !== null) {
        H2O.prototype.destroyAnnotationMarkup(this.annotation_deleted_id);
        H2O.prototype.resetUnlayered(h2o_global.getItemId());
        H2O.prototype.manageLayers(this.annotation_deleted_id, 'deleted');
        $('span#annotation-indicator-' + this.annotation_deleted_id).remove();
        collages.updateWordCount();
      }
    });
    this.annotator.editor.subscribe("hide", function() {
      $('span#layer_error').remove();
      $('#add_new_layer').siblings('div').remove();
      $('#collage_search,#collage_search_buttons').hide();
      $('#link_to_collage').show();
    });

    /* Field management */
    this.annotator.editor.addField({
      id: 'linked_collage_id',
      type: 'input',
      label: 'Link to Collage'
    });
    var cat, color, _ref;
    _ref = this.categories;
    for (cat in this.categories) {
      color = this.categories[cat];
      this.annotator.editor.addField({
        id: 'layer-' + cat,
        type: 'checkbox',
        label: cat,
        value: cat
      });
      this.layer_map = this.categories;
    }
    this.annotator.editor.addField({
      load: this.updateEditor
    });
    this.annotator.viewer.addField({
      load: this.updateViewer
    });
    this.annotator.editor.addField({
      id: 'add_new_layer_placeholder',
      type: 'input',
      label: 'Add New Layer'
    });
  };

  H2O.prototype.addAnnotationIndicator = function(annotation) {
    var first_highlight = $('.annotation-' + annotation.id + ':first');
    var last_highlight = $('.annotation-' + annotation.id + ':last');
    if(first_highlight.size() > 0) {
      var start_position = first_highlight.position().top;
      var class_name = 'annotation-indicator';
      $.each(annotation.layers, function(i, el) {
        class_name += ' annotation-indicator-' + el;
      });
      var height = last_highlight.position().top + last_highlight.height() - start_position;
      $('.annotator-wrapper').prepend($('<span>').attr('data-id', annotation.id).addClass(class_name).attr('id', 'annotation-indicator-' + annotation.id).css({ 'top' : start_position, 'height' : height }));
    }
  };
  H2O.prototype.updateAllAnnotationIndicators = function() {
    $.each($('.annotation-indicator'), function(i, el) {
      h2o_annotator.plugins.H2O.updateAnnotationIndicator($(el).data('id'));
    });
  };
  H2O.prototype.updateAnnotationIndicator = function(annotation_id) {
    var first_highlight = $('.annotation-' + annotation_id + ':first');
    var last_highlight = $('.annotation-' + annotation_id + ':last');
    if(first_highlight.size() > 0) {
      var start_position = first_highlight.position().top;
      var height = last_highlight.position().top + last_highlight.height() - start_position;
      $('span#annotation-indicator-' + annotation_id).css({ 'top' : start_position, 'height' : height }).show();
    }
  };


  H2O.prototype.manageLayers = function(annotation, type) {
    if(type == 'created' || type == 'updated') {
      h2o_annotator.editor.element.find('#add_new_layer').parent().remove();
      h2o_annotator.editor.fields.pop();
      $.each(annotation.layers, function(i, layer) {
        if($('#layers_highlights li[data-name=' + layer + ']').size() == 0) {
          if(layer != 'required') {
            h2o_annotator.editor.addField({
              id: 'layer-' + layer,
              type: 'checkbox',
              label: layer,
              value: layer
            });
          }
          
          //Manage li options
          var data = { hex: h2o_annotator.plugins.H2O.layer_map[layer], layer: layer };
          var new_node = $(jQuery.mustache(layer_tools_visibility, data));
          new_node.appendTo($('#layers'));
          var new_node2 = $(jQuery.mustache(layer_tools_highlights, data));
          new_node2.appendTo($('#layers_highlights'));
        }
      });
      h2o_annotator.editor.addField({
        id: 'add_new_layer_placeholder',
        type: 'input',
        label: 'Add New Layer'
      });
      $('<a>').attr('id', 'add_new_layer').html('Add New Layer').insertAfter($('#add_new_layer_placeholder'));
      $('#add_new_layer_placeholder').hide();
    } else if(type == 'deleted') {
      $.each($('#layers_highlights li'), function(i, el) {

        if($('span.layer-' + collages.clean_layer($(el).data('name')) + ':not(.annotator-collage *)').not('.annotation-' + annotation).size() == 0) {
          if($(el).data('name') != 'required') {
            var updated_fields = new Array();

            for(var _j = 0; _j < h2o_annotator.editor.fields.length; _j++) {
              if(h2o_annotator.editor.fields[_j].id != 'layer-' + $(el).data('name')) {
                updated_fields.push(h2o_annotator.editor.fields[_j]);
              } else {
                h2o_annotator.editor.element.find('#layer-' + $(el).data('name')).parent().remove();
              }
            }
            h2o_annotator.editor.fields = updated_fields;
        
            $('.annotator-listing li.' + collages.clean_layer($(el).data('name'))).remove();
          }
          $("#layers li[data-name='" + $(el).data('name') + "']").remove();
          $(el).remove(); 
        }
      });
    }
  };
  
  H2O.prototype.updateAnnotationMarkup = function(annotation) {
    var class_string = 'annotator-hl annotation-' + annotation.id;
    for(var _i = 0; _i < annotation.layers.length; _i++) {
      var _l = annotation.layers[_i];
      class_string += ' layer-' + _l;
      if($("#layers_highlights li[data-name='" + _l + "']").size() &&
        $("#layers_highlights li[data-name='" + _l + "'] a").html().match(/^UNHIGHLIGHT/)) {
        class_string += ' highlight-' + _l;
      }
    }
    $('.annotation-' + annotation.id).attr('class', class_string);
  };

  H2O.prototype.destroyAnnotationMarkup = function(annotation_id) {
    var first_highlight = $('.delete-' + annotation_id + ':first');

    var prev_node = first_highlight.prev('.unlayered-' + first_highlight.data('unlayered'));
    var last_highlight = $('.delete-' + annotation_id + ':last');
    var next_node = last_highlight.next('.unlayered-' + last_highlight.data('unlayered'));

    if($('.delete-' + annotation_id).size() == 1 && prev_node.size() > 0 && next_node.size() > 0) {
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
    $('.delete-' + annotation_id).removeClass('delete-' + annotation_id);
  };
  
  H2O.prototype.beforeDestroyAnnotationMarkup = function(annotation) {
    $('.layered-control-start-' + annotation.id + ',.layered-ellipsis-' + annotation.id + ',.layered-control-end-' + annotation.id).remove();
  
    var all_items = $('.unlayered,.annotator-hl');
    var highlights = $('.annotation-' + annotation.id);
  
    // if annotation.highlight first previous is unlayered
    var front_unlayered = false;
    var first_pos = all_items.index(highlights[0]);
    var prev_node = $(all_items[first_pos - 1]);
    if(prev_node.is('.unlayered') && $(highlights[0]).parents('.annotator-hl').size() == 0) {
      front_unlayered = true;
    }
    // if annotation.highlight last next is unlayered
    var back_unlayered = false;
    var last_highlight = highlights[highlights.length - 1];
    var last_pos = all_items.index(last_highlight);
    var next_node = $(all_items[last_pos + 1]);
    if($(last_highlight).parents('.annotator-hl').size() == 0 && (last_pos != (all_items.size() - 1)) && (next_node.is('.unlayered'))) {
      back_unlayered = true;
    }

    if(front_unlayered && back_unlayered && ($(highlights).children('.annotator-hl').size() > 0 || $(highlights).parents('.annotator-hl').size() > 0)) {
      for(var _i = 0; _i < highlights.length; _i++) {
        var contents = $(highlights[_i]).contents();
        for(var _j = 0; _j < contents.length; _j++) {
          var parent_count = $(contents[_j]).parents('.annotator-hl:not(.annotation-' + annotation.id + ')').size();
          if(contents[_j].nodeType == 3 && parent_count == 0) {
            var updated = '<span class="delete-' + annotation.id + ' unlayered">' + $(contents[_j]).text() + '</span>';
            $(contents[_j]).replaceWith(updated); 
          }
        }
      }
    } else if(front_unlayered || back_unlayered) {
      for(var _i = 0; _i < highlights.length; _i++) {
        if($(highlights[_i]).parents('.annotator-hl').size() == 0) {
          var contents = $(highlights[_i]).contents();
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
      if(annotations[_i].layers !== undefined) {
        var layer_class = annotations[_i].layers.join(' ');
      }
      var start_node = $('.annotation-' + _id + ':first');
      var end_node = $('.annotation-' + _id + ':last');
      $('<a href="#" class="layered-control-start layered-control-start-' + _id + ' ' + collages.clean_layer(layer_class) + '" data-layered="' + _id + '"></a>').insertBefore(start_node);
      $('<a href="#" class="layered-ellipsis layered-ellipsis-' + _id + ' ' + collages.clean_layer(layer_class) + '" data-layered="' + _id + '">[...]</a>').insertBefore(start_node);
      $('<a href="#" class="layered-control-end layered-control-end-' + _id + ' ' + collages.clean_layer(layer_class) + '" data-layered="' + _id + '"></a>').insertAfter(end_node);
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

  H2O.prototype.resetUnlayered = function(c_id) {
    //resetting parents that have no annotator children to unlayered, and resetting unlayered children inside
    var collage_selector = $('#collage' + c_id);
    $.each(collage_selector.find('.annotator-wrapper .original_content:not(.annotator-hl,.unlayered *, .unlayered,:has(.annotator-hl),br)'), function(i, el) {
      $(el).addClass('unlayered');
      $.each($(el).find('.unlayered'), function(j, unlayered_el) {
        $(unlayered_el).contents().unwrap();
      });
      $(el).find('.unlayered-control-start,.unlayered-control-end,.unlayered-ellipsis').remove();
    });

    //removing any unlayered control borders, ellipsis for not needed anymore
    var all_items = collage_selector.find('.unlayered-control-start,.unlayered-control-end,.unlayered:not(:has(.unlayered)),.annotator-hl');

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

    all_items = collage_selector.find('.unlayered:not(:has(.unlayered)),.annotator-hl');
    var unlayered = 0;

    if(all_items.first().is('.unlayered')) {
      var _this = all_items.first();
      if(!_this.prev().is('.unlayered-ellipsis')) {
        collage_selector.find('.unlayered-control-first,.unlayered-ellipsis-first').remove();
        $('<a href="#" class="unlayered-control-start unlayered-control-first unlayered-control-start-' + unlayered + '" data-unlayered="' + unlayered + '"></a>').insertBefore(_this);
        $('<a href="#" class="unlayered-ellipsis unlayered-ellipsis-first unlayered-ellipsis-' + unlayered + '" data-unlayered="' + unlayered + '">[...]</a>').insertBefore(_this);
      } else {
        _this.prev().removeClass('unlayered-ellipsis-' + _this.prev().data('unlayered')).addClass('unlayered-ellipsis-' + unlayered).data('unlayered', unlayered);
        _this.prev().prev().removeClass('unlayered-control-start-' + _this.prev().prev().data('unlayered')).addClass('unlayered-control-start-' + unlayered).data('unlayered', unlayered);
      }
    } else {
      collage_selector.find('.unlayered-control-first,.unlayered-ellipsis-first').remove();
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
        collage_selector.find('.unlayered-control-last').remove();
        $('<a href="#" class="unlayered-control-end unlayered-control-last unlayered-control-end-' + unlayered + '" data-unlayered="' + unlayered + '"></a>').insertAfter(_this);
      } else {
        _this.next().removeClass('unlayered-control-end-' + _this.next().data('unlayered')).addClass('unlayered-control-end-' + unlayered).data('unlayered', unlayered);
      }
    } else {
      collage_selector.find('.unlayered-control-last').remove();
    }
  };

  H2O.prototype.setUnlayeredSingle = function(annotation) {
    $.each(annotation._local.highlights, function(_i, el) {
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
  };

  H2O.prototype.setAllUnlayered = function(c_id) {
    var element = this.annotator.element;

    $('div.article *:not(.paragraph-numbering)').addClass('original_content');
    element.find('.annotator-wrapper .original_content:not(.annotator-hl,:has(.annotator-hl),br)').addClass('unlayered');
    element.find('.unlayered .unlayered').removeClass('unlayered');

    $.each(element.find('.annotator-wrapper .original_content:not(.unlayered, .unlayered *)'), function(i, el) {
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

    this.resetUnlayered(c_id);
  };

  H2O.prototype.setUnlayeredListeners = function() {
    $(document).delegate('.unlayered-ellipsis', 'click', function(e) {
      e.preventDefault();
      var key = $(this).data('unlayered');
      $('.unlayered-' + key).show();
      $('.unlayered-control-start-' + key + ',.unlayered-control-end-' + key).css('display', 'inline-block');
      $(this).hide();
      collages.hideShowUnlayeredOptions();
      h2o_annotator.plugins.H2O.updateAllAnnotationIndicators();
    });
    $(document).delegate('.unlayered-control-start,.unlayered-control-end', 'click', function(e) {
      e.preventDefault();
      var key = $(this).data('unlayered');
      $('.unlayered-' + key).hide();
      $('.unlayered-ellipsis-' + key).show();
      $('.unlayered-control-start-' + key + ',.unlayered-control-end-' + key).hide();
      collages.hideShowUnlayeredOptions();
      h2o_annotator.plugins.H2O.updateAllAnnotationIndicators();
    });
  };

  H2O.prototype.setHighlights = function(annotation) {
    var h, _i, _len, _results;
    _results = [];
    $.each(annotation._local.highlights, function(_i, h) {
      h = annotation._local.highlights[_i];
      for(_c = 0; _c < annotation.layers.length; _c++) { 
        var _l = annotation.layers[_c];
        _results.push(h.className = h.className + ' layer-' + collages.clean_layer(_l));
        if($("#layers_highlights li[data-name='" + _l + "']").size() &&
          $("#layers_highlights li[data-name='" + _l + "'] a").html().match(/^UNHIGHLIGHT/)) {
          _results.push(h.className = h.className + ' highlight-' + collages.clean_layer(_l));
        }
      }
    });

    return;
  };

  H2O.prototype.updateEditor = function(field, annotation) {
    $('.annotator-checkbox input').prop('checked', false);
    if(annotation.id !== undefined) {
      //annotation is not new
      $.each(annotation.layers, function(i, layer) {
        $('input#layer-' + layer).prop('checked', true);
      });

      if(annotation.linked_collage_id === null || annotation.linked_collage_id === undefined) {
        $('#existing_collage_link,#cancel_link_to_collage').hide();
        $('#link_to_collage').show();
      } else {
        $('#existing_collage_link span').html('Linked Collage: ' + linked_collages["c" + annotation.linked_collage_id]);
        $('#linked_collage_id').val(annotation.linked_collage_id);
        $('#link_to_collage').hide();
        $('#existing_collage_link,#edit_link_to_collage').show();
      }
    } else {
      //annotation is new
      $.each(annotation.layer_hexes, function(i, el) {
        $('input#layer-' + el.layer).prop('checked', true);
      });
    }

    $(field).hide();
  };

  H2O.prototype.updateViewer = function(field, annotation) {
    if($('#print-options').size() > 0) {
      return;
    }

    field = $(field);
    field.addClass('annotator-collage').hide();

    if(annotation.linked_collage_id !== null) {
      field.show();
      field.append($('<div id="viewer_linked_collage">Linked Collage: <a target="_blank" href="/collages/' + annotation.linked_collage_id + '">' + linked_collages["c" + annotation.linked_collage_id] + '</a></div>'));
    }

    $('.annotator-controls').css('visibility', 'visible');
    if(annotation.layers !== undefined) {
      for(_c = 0; _c < annotation.layers.length; _c++) {
        var layer = annotation.layers[_c];
        var clean_layer = collages.clean_layer(layer);
        if(field.find('span.' + clean_layer).size() == 0) {
            var hex = h2o_annotator.plugins.H2O.layer_map[layer];
            var color_combine = jQuery.xcolor.opacity('#FFFFFF', hex, 0.4);
            field.append($('<span>').attr('style', 'background-color:' + color_combine.getHex()).html(layer).addClass('layer-' + clean_layer));
        }
      }
      field.show();
    }
  };

  H2O.prototype.format_annotations = function(current_annotations) {
    var formatted_annotations = [];
    $.each(current_annotations, function(i, el) {
      var annotation = JSON.parse(el);
      var ranges = [{
            "start": annotation.xpath_start,
            "end": annotation.xpath_end,
            "startOffset": annotation.start_offset,
            "endOffset": annotation.end_offset
      }];
      var layers = new Array();
      for(var _j = 0; _j < annotation.layers.length; _j++) {
        layers.push(annotation.layers[_j].name);
      }
      var formatted_annotation = { "id" : annotation.id,
        "text" : annotation.annotation,
        "ranges": ranges,
        "layers": layers,
        "cloned": annotation.cloned,
        "collage_id" : annotation.collage_id,
        "linked_collage_id" : annotation.linked_collage_id
      };
      formatted_annotation.ranges = ranges;
      formatted_annotations.push(formatted_annotation);
    });

    return formatted_annotations;
  };

  H2O.prototype.loadAnnotations = function(c_id, current_annotations, page_load) {
    if(page_load) {
      this.setAllUnlayered(c_id);
      this.setUnlayeredListeners();
      this.collage_id = c_id;
    }

    var data = this.format_annotations(current_annotations);
    h2o_annotator.loadAnnotations(data);
  }
 
  H2O.prototype.removeAnnotationMarkupAndUnlayered = function(annotation) {
    h2o_annotator.publish('beforeAnnotationDeleted', [annotation]);
    this.removeAnnotationMarkup(annotation);
    this.destroyAnnotationMarkup(annotation.id);
  };

  H2O.prototype.removeAnnotationMarkup = function(annotation) {
    var child, h, _k, _len2, _ref1;
    var highlights = $('.annotation-' + annotation.id); 
    _ref1 = highlights;
    for (_k = 0, _len2 = _ref1.length; _k < _len2; _k++) {
      h = _ref1[_k];
      if (!(h.parentNode != null)) {
        continue;
      }
      child = h.childNodes[0];
      $(h).replaceWith(h.childNodes);
    }

    return;
  };

  return H2O;

})();

Annotator.Plugin.register('H2O', H2O);

module.exports = H2O;

},{}]},{},[3])

(3)
});
