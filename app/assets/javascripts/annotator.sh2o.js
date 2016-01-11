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

Annotator.prototype.html.adder = '<div class="annotator-adder">'
  + '<a id="adder_hide_one_click" class="icon icon-adder-hide-one-click" href="#" title="hide">eyeball</a>'
  + '<a id="adder_hide" class="icon icon-adder-hide" href="#" title="replace text">eyeball-t</a>'
  + '<div></div>'
  + '<a href="#" id="adder_link" class="icon icon-adder-link" title="link">link</a>'
  + '<a href="#" id="adder_highlight" class="icon icon-adder-highlight" title="highlight">pencil</a>'
  + '<a id="adder_annotate" class="icon icon-adder-annotate" href="#" title="annotate">quote</a>'
  + '<a id="adder_feedback" href="#" class="icon icon-feedback" title="Feedback">Feedback</a>'
  + '<a id="adder_discuss" href="#" class="icon icon-discuss" title="Discuss">Discuss</a>'
  + '<button id="adder_button" type="button"></button>'
  + '</div>';
Annotator.Editor.prototype.html = '<div class="annotator-outer annotator-editor"><form class="annotator-widget"><ul class="annotator-listing"></ul><div class="annotator-controls"><a href="#cancel" class="annotator-cancel"></a><a href="#" id="h2o_delete">Delete</a><a href="#save" class="annotator-save annotator-focus">Save</a></div></form></div>';


$ = Annotator.Util.$;

H2O = (function() {
  function H2O(categories, highlights_only, report_options, can_edit) {
    this.categories = categories;
    this.highlights_only = highlights_only;
    this.formatted_annotations = {};
    this.annotation_deleted_id = null;
    this.initialized = false;
    this.can_edit = can_edit;
    this.can_leave_feedback = report_options["feedback"];
    this.can_discuss = report_options["discuss"];
    this.can_respond = report_options["respond"];
    this.can_report = report_options["report"];
    this.annotated_item_id = 0;
    this.updateViewer = __bind(this.updateViewer, this);
    this.updateEditor = __bind(this.updateEditor, this);
    this.accessible_annotations = {};
    this.annotation_indicator_map = {};
  }

  H2O.prototype.field = null;

  H2O.prototype.input = null;

  H2O.prototype.pluginInit = function() {
    if(h2o_annotator.plugins.H2O.can_edit) {
      $(document).delegate('#link', 'click', function(e) {
        if($(this).val() == '') {
          $(this).val('http://').select();
        }
      });
      $(document).delegate('.annotator-checkbox:not(.annotation_hidden_property) label, .annotator-checkbox2 label', 'click', function(e) {
        $('.annotator-checkbox input, .annotator-checkbox2 input').prop('checked', false);
        $(this).siblings('input').prop('checked', true);
        $('.annotator-save').trigger('click');
      });
      $(document).delegate('#h2o_delete,#remove_edit_quicklink', 'click', function(e) {
        e.preventDefault();
        h2o_annotator.editor.hide();
        $('.annotator-delete').trigger('click');
      });
    }

    $(document).delegate('body', 'click', function(e) {
      if($(e.target).hasClass('icon-edit') ||
         $(e.target).hasClass('icon-delete') ||
         $(e.target).parent().hasClass('annotator-adder') || 
         $(e.target).hasClass('annotator-edit') || 
         $(e.target).hasClass('annotation-indicator') || 
         $(e.target).parent().hasClass('annotation-indicator')) {
        return;
      }
      if($(e.target).parents('.annotator-editor').length == 0 && $('.annotator-editor .annotator-controls').is(':visible')) {
        $('.annotator-cancel').trigger('click');
      }
    });

    $(document).delegate('.annotation-indicator-annotate,.annotation-indicator-link,.icon-adder-annotate,.icon-adder-link,.annotation-indicator-discuss,.annotation-indicator-feedback', 'mouseover', function(e) {
      $('.annotation-' + $(this).data('id')).addClass('with_comment');
      $('span.readonly-link,span.readonly-annotate').css('z-index', 99);
      $('#annotation-indicator-' + $(this).data('id')).find('span').css('z-index', 100);
    });
    $(document).delegate('.annotation-indicator-error', 'mouseover', function(e) {
      $('.annotation-' + $(this).data('id')).addClass('with_error');
      $('span.readonly-error').css('z-index', 99);
      $('#annotation-indicator-' + $(this).data('id')).find('span').css('z-index', 100);
    });
    $(document).delegate('.annotation-indicator-annotate,.annotation-indicator-link,.icon-adder-annotate,.icon-adder-link,.annotation-indicator-discuss,.annotation-indicator-feedback', 'mouseout', function(e) {
      $('.annotation-' + $(this).data('id')).removeClass('with_comment');
    });
    $(document).delegate('.annotation-indicator-error', 'mouseout', function(e) {
      $('.annotation-' + $(this).data('id')).removeClass('with_error');
    });

    $(document).delegate('#stats_expand', 'click', function(e) {
      $('#stats_collapse').slideDown(100, function() {
        var height_offset = $('div#stats').data('height_offset');
        $.each($('.edit-annotate:visible, .edit-link:visible, .delete-feedback:visible, .readonly-link'), function(i, el) {
          if($(el).offset().top < height_offset) {
            $(el).hide(); 
          }
        });
        $('#stats_expand').hide();
      });
    });

    $(document).delegate('.icon-adder-annotate,.icon-adder-link,.icon-adder-error,.icon-adder-feedback', 'click', function(e) {
      if($('div#stats').is(':visible')) {
        var height_offset = $('div#stats').offset().top + $('div#stats').height();
        if(height_offset > $(this).offset().top) {
          $('div#stats').data('height_offset', height_offset);
          $('div#stats_collapse').slideUp(100, function() {
            $('#stats_expand').css('display', 'block');
          });
        }
      }
    });

    if(h2o_annotator.plugins.H2O.can_edit || h2o_annotator.plugins.H2O.can_leave_feedback) {
      $(document).delegate('.delete-error .icon-delete,.delete-feedback .icon-delete', 'click', function(e) {
        e.preventDefault();
        var annotation = h2o_annotator.plugins.H2O.accessible_annotations[$(this).parent().parent().data('id')];
        h2o_annotator.editor.annotation = annotation;
        var position = $(this).parent().parent().position();
        position.top += 4;
        position.left += 9;
        h2o_annotator.showViewer([annotation], position);
        $('.annotator-delete').trigger('click');
      });
    }

    if(h2o_annotator.plugins.H2O.can_edit) {
      $(document).delegate('.icon-adder-annotate,.icon-adder-link,.icon-adder-error,.icon-adder-discuss,.icon-adder-feedback', 'click', function(e) {
        e.preventDefault();
        $(this).siblings('.edit-annotate,.edit-link,.delete-error,.delete-feedback').find('.icon-edit,.icon-trash').show();
        $(this).css({ 'opacity': 1.0 });
        $(this).siblings('.edit-annotate,.edit-link,.delete-error,.delete-feedback').toggle();
      });
      $(document).delegate('.edit-annotate .icon-edit,.edit-link .icon-edit', 'click', function(e) {
        e.preventDefault();
        var annotation = h2o_annotator.plugins.H2O.accessible_annotations[$(this).parent().parent().data('id')];
     
        var position = $(this).parent().parent().position();
        position.top += 4;

        position.left += 9;

        if($(this).parent().hasClass('edit-annotate')) {
          $('.annotator-editor').data('type', 'annotate');
          $('.annotator-listing textarea').parent().show();
          $('.annotator-listing textarea').attr('placeholder', 'Comments...');
        } else {
          $('.annotator-editor').data('type', 'link');
          $('.annotator-listing input#link').parent().show();
          $('input#link').val(annotation.link);
        }
        $('.annotator-adder button').trigger('click');

        $(this).parent().hide();

        h2o_annotator.showViewer([annotation], position);
        $('.annotator-edit').trigger('click');
        h2o_annotator.editor.annotation = annotation;

        if($(this).parent().hasClass('edit-annotate')) {
          $('.annotator-listing textarea').focus();
        } else {
          $('.annotator-listing input#link').focus();
        }
      });
      $(document).delegate('.annotation-indicator:not(.annotation-indicator-annotate,.annotation-indicator-link,.annotation-indicator-error,.annotation-indicator-feedback)', 'click', function(e) {
        e.preventDefault();
        var annotation = h2o_annotator.plugins.H2O.accessible_annotations[$(this).data('id')];

        var position = $(this).position();
        position.top += 4;
        if ($(this).hasClass('annotation-indicator-highlights') || $(this).hasClass('icon-adder-highlight-only')) {
          position.left += $(this).find('a').width()/2;
          $('.annotator-editor').data('type', 'highlight');
          $('.annotator-listing .annotator-checkbox:not(.annotation_hidden_property), .annotator-listing .annotator-checkbox2').show();
          $('#new_layer').parent().show();
          $('.annotator-adder button').trigger('click');
        } else if ($(this).hasClass('icon-adder-show')) {
          position.left += 11;
          $('.annotator-editor').data('type', 'hide');
          $('.annotator-listing textarea').attr('placeholder', 'Enter replacement text...');
          $('.annotation_hidden_property').show();
          $('#h2o_delete').hide();
          $('.annotator-listing textarea').parent().show();
        }
        h2o_annotator.showViewer([annotation], position);
        $('.annotator-edit').trigger('click');
        h2o_annotator.editor.annotation = annotation;
      });
    } else if(h2o_annotator.plugins.H2O.can_report) {
      $(document).delegate('.annotation-indicator', 'click', function(e) {
        if($(e.target).hasClass('link')) {
          return;
        }
        if($(this).find('span.icon-adder-link').size() > 0) {
          $('span.readonly-link,span.readonly-annotate').css('z-index', 99);
          $(this).find('span.readonly-link').css('z-index', 100).toggle();
        } 
        if($(this).find('span.icon-adder-annotate').size() > 0) {
          $('span.readonly-link,span.readonly-annotate').css('z-index', 99);
          $(this).find('span.readonly-annotate').css('z-index', 100).toggle();
        }
        if($(this).find('span.icon-adder-error').size() > 0) {
          $('span.readonly-link,span.readonly-annotate,span.delete-error').css('z-index', 99);
          $(this).find('span.delete-error').css('z-index', 100).toggle();
        }
        if($(this).find('span.icon-adder-feedback').size() > 0) {
          $('span.readonly-link,span.readonly-annotate,span.delete-feedback').css('z-index', 99);
          $(this).find('span.delete-feedback').css('z-index', 100).toggle();
        }
        return;
      });
    } else {
      $(document).delegate('.icon-adder-annotate,.icon-adder-link,.icon-adder-error,.icon-adder-discuss,.icon-adder-feedback', 'click', function(e) {
        e.preventDefault();
        $(this).css({ 'opacity': 1.0 });
        $(this).siblings('.readonly-annotate, .readonly-link').toggle();
      });
    }

    $(document).delegate('.annotator-adder > a:not(.hexes a)', 'click', function(e) {
      e.preventDefault();
      $('.annotator-adder a.active').removeClass('active');
      $(this).addClass('active');
      $('.annotator-controls a').show();
      $('.annotator-listing li, #h2o_delete').hide();
      $('.annotator-editor').data('type', 'new_item');
      $('#link').val('');

      //TODO: Change this to test
      if($(this).attr('id') == 'adder_annotate' || $(this).attr('id') == 'adder_error' || $(this).attr('id') == 'adder_feedback' || $(this).attr('id') == 'adder_discuss' || $(this).attr('id') == 'adder_hide') {
        $('.annotator-editor').data('type', $(this).attr('id').replace(/^adder_/, ''));
        $('.annotator-listing textarea').parent().show();
        $('.annotator-adder button').trigger('click');
        $('.annotator-listing textarea').focus();
        if($(this).attr('id') == 'adder_annotate') {
          $('#annotator-field-0').attr('placeholder', 'Comments...');
        } else if($(this).attr('id') == 'adder_error') {
          $('#annotator-field-0').attr('placeholder', 'Report Error...');
        } else if($(this).attr('id') == 'adder_feedback') {
          $('#annotator-field-0').attr('placeholder', 'Report Feedback...');
        } else if($(this).attr('id') == 'adder_hide' || $(this).attr('id') == 'adder_hide_one_click') {
          $('#annotator-field-0').attr('placeholder', 'Enter replacement text...');
        }
      } else if ($(this).attr('id') == 'adder_highlight') {
        $('.annotator-editor').data('type', 'highlight');
        $('.annotator-listing .annotator-checkbox:not(.annotation_hidden_property), .annotator-listing .annotator-checkbox2').show();
        $('#new_layer').parent().show();
        $('.annotator-adder button').trigger('click');
      } else if($(this).attr('id') == 'adder_hide_one_click') {
        $('.annotator-editor').data('type', 'hide');
        $('.annotator-adder button').trigger('click');
        $('.annotator-save').trigger('click');
      } else {
        $('.annotator-editor').data('type', 'link');
        $('.annotator-listing input#link').parent().show();
        $('.annotator-adder button').trigger('click');
        $('.annotator-listing input#link').focus();
      }
    });

    this.annotator.subscribe("annotationsLoaded", function(annotations) {
      var annotated_item_id = this.plugins.H2O.annotated_item_id;

      $('#annotator-field-0').addClass('no_tinymce');

      $.each(annotations, function(i, annotation) {
        $(annotation._local.highlights).addClass('annotation-' + annotation.id);
      });

      if(this.initialized) {
        return;
      }

      this.initialized = true;

      var annotations_count = Object.keys(annotations).length;
      $.each(annotations, function(i, annotation) {
        H2O.prototype.setLayeredBorders(annotation);

        var single_anno_start = new Date();
        if(annotation.hidden) {
          H2O.prototype.applyHiddenAnnotation(annotation);
        } else {
          H2O.prototype.setHighlights(annotation, false);
        }

        if (!$('#print-options').length) {
          H2O.prototype.addAnnotationIndicator(annotation);
          h2o_annotator.plugins.H2O.accessible_annotations[annotation.id] = annotation;
        }
      });

      collages.rehighlight();

      if (h2o_annotator.options.readOnly) {
        access_results = { can_edit: false };
      }

      if (!!$('#collage_print').length) {
        collages.loadState($('.singleitem').data('itemid'), original_data);
      }
      if (!!$('#print-options').length) {
        collages.loadState(
          annotated_item_id,
          all_collage_data["collage" + annotated_item_id].data
        );
      } else {
        console.log('Missing #print-options');
      }

      if (!$('#print-options').length) {
        //Skip extraneous work that doesn't apply to print-options. Might be able to skip
        //this for collage_print too, but I didn't have time to prove that.

        //loadState has to be before listenTo
        if(!h2o_annotator.options.readOnly) {
          collages.listenToRecordAnnotatedItemState();
        }

        $('.annotator-edit,.annotator-delete').css('opacity', 0.0);
        $('#show_annotation').hide().parent().addClass('annotation_hidden_property');

        collages.getHexes().insertAfter($('#new_layer'));

        $('<a>').attr('id', 'remove_edit_quicklink').html('Remove edit?').insertAfter($('input#show_annotation'));
        $('.annotator-listing li').hide();
        $('.annotator-checkbox input').prop('checked', false);
        $('.annotator-controls a, #h2o_delete').show();
        $('#link').val('');
      }

      h2o_global.slideToAnnotation();

      try {
        //TODO: rename these vars and make them attributes of the H2O object
        phunk_start = phunk_start || new Date();
        phunk_last = phunk_last || new Date();

        var now = new Date()
        var incTime = (now - phunk_last);
        phunk_last = now;
        var incTimeSeconds = incTime / 1000;
        var elapsed = parseInt((now - phunk_start)/1000);

        //Track the loading of all the collages' annotations
        all_collage_data["collage" + annotated_item_id].done_loading = true;

        var done_count = 0;

        //TODO: encapsulate this loading_done? check into its own function
        var done_loading = true;
        $.each(all_collage_data, function(id, annotation) {
          if (!annotation.done_loading) {
            done_loading = false;
            return;
          } else {
            done_count++;
          }
        });

        //console.log('al_duration: ' + ((new Date() - starttime)/1000) + 's');
        console.log('annotationsLoaded for annotated_item_id: ' + annotated_item_id +
                    ' - ' + annotations_count + ' in ' +
                    incTimeSeconds + 's of ' +
                    elapsed + 's total' +
                    ' - (' + done_count + '/' + Object.keys(all_collage_data).length + ')'
                   );

        if (done_loading && export_functions) {
          export_functions.loadAllAnnotationsComplete();
        }
      } catch(e) {console.log('annotationsLoaded warning: ' + e);}

    });

    this.annotator.subscribe("annotationEditorSubmit", function(editor) {
      if($('#show_annotation').attr('checked')) {
        editor.annotation.force_destroy = true;
      }

      editor.annotation.link = $('input#link').val();
      editor.annotation.layer_hexes = [];
      editor.annotation.highlight_only = undefined;
      var old_layer = false

      /* Layer with color mapping */
      $.each($('.annotator-editor li.annotator-checkbox input:not(#show_annotation)'), function(_i, el) {
        if($(el).is(':checked')) {
          old_layer = true;
          var layer_name = $(el).attr('id').replace(/^layer-/, '');
          layer_name = collages.revert_clean_layer(layer_name);
          editor.annotation.layer_hexes.push({ layer: layer_name, hex: h2o_annotator.plugins.H2O.layer_map[layer_name], is_new: false });
        }
      });

      var hex = $('.annotator-listing .hexes .active');
      var new_layer = !old_layer && $('input#new_layer').val() != '' && (hex.size() > 0 || $('.annotator-editor').data('type') == 'highlight')
      if(new_layer) {
        if(hex.size() < 1) {
          hex = $($('.annotator-listing .hexes a:not(.inactive)')[0]);
        }
        editor.annotation.layer_hexes = [{ layer: $('input#new_layer').val().toLowerCase(), hex: hex.text(), is_new: true }];
        h2o_annotator.plugins.H2O.layer_map[$('input#new_layer').val().toLowerCase()] = hex.text();
      }

      /* Highlight Only */
      if(!old_layer && !new_layer && hex.size() == 1) {
        editor.annotation.layer_hexes = [];
        editor.annotation.highlight_only = hex.text();
      }
      $.each($('.annotator-editor li.annotator-checkbox2 input'), function(_i, el) {
        if($(el).is(':checked')) {
          editor.annotation.highlight_only = $(el).attr('id').replace(/^highlight-only-/, '');
        }
      });
      if(!old_layer && !new_layer && $('.annotator-editor').data('type') == 'highlight' && editor.annotation.highlight_only == undefined) {
        var default_hex = $($('.annotator-listing .hexes a:not(.inactive)')[0]);
        if(default_hex.length < 1) {
          default_hex = $($('.annotator-listing .hexes a')[0]);
        }
        editor.annotation.highlight_only = default_hex.text();
      }

      var node = $('.layered-ellipsis-' + editor.annotation.id)
      if(node.length > 0) {
        var text = editor.annotation.text.length > 0 ? editor.annotation.text : '...';
        node.html('[' + text + ']');
        $('.annotation-' + editor.annotation.id).hide();
      }

      editor.annotation.error = $('.annotator-editor').data('type') == 'error';
      editor.annotation.discuss = $('.annotator-editor').data('type') == 'discuss';
      editor.annotation.feedback = $('.annotator-editor').data('type') == 'feedback';
      editor.annotation.hidden = $('.annotator-editor').data('type') == 'hide';
    });

    this.annotator.subscribe("annotationCreated", function(annotation) {
      annotation.layers = $.parseJSON(annotation.layers);
      annotation.text = annotation.text;
      $(annotation._local.highlights).addClass('annotation-' + annotation.id);
      H2O.prototype.addAnnotationIndicator(annotation);
      h2o_annotator.plugins.H2O.accessible_annotations[annotation.id] = annotation;
      H2O.prototype.setLayeredBorders(annotation);

      if(annotation.hidden) {
        if($('#show_text_edits .toggle-inner .toggle-on').hasClass('active')) {
          $('.annotation-' + annotation.id).addClass('annotation-hidden');
          $('.layered-control-start-' + annotation.id + ',.layered-control-end-' + annotation.id).css('display', 'inline-block');
        } else {
          $('.annotation-' + annotation.id).addClass('annotation-hidden').hide();
          $('.layered-ellipsis-' + annotation.id).css('display', 'inline-block');
          $('.annotation-' + annotation.id).parents('.original_content').filter(':not(.original_content *):not(:has(.annotator-hl:visible,.layered-ellipsis:visible))').hide();
          $.each($('.annotation-' + annotation.id).parents('.original_content').filter(':not(.original_content *)'), function(i, j) {
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
        }
        h2o_annotator.plugins.H2O.updateAllAnnotationIndicators();
        return;
      }
      if(annotation.layers.length) {
        //Assume there is only one layer
        var clean_layer = collages.clean_layer(annotation.layers[0]);
        if($('#layers_highlights li.user_layer[data-name="' + clean_layer + '"] .toggle-show_hide .toggle-off').hasClass('active')) {
          $('.annotation-' + annotation.id + ',#annotation-indicator-' + annotation.id + ',#annotation-bar-indicator-' + annotation.id).hide();
          $('.layered-ellipsis-' + annotation.id).css('display', 'inline-block');
          $('.annotation-' + annotation.id).parents('.original_content').filter(':not(.original_content *):not(:has(.annotator-hl:visible,.layered-ellipsis:visible))').hide();
        } 
      }

      //Manage layers before highlights
      H2O.prototype.manageLayers(annotation, 'created');
      H2O.prototype.setHighlights(annotation, true);
      collages.rehighlight();
    });
    this.annotator.subscribe("annotationUpdated", function(annotation) {
      if(annotation.force_destroy !== undefined && annotation.force_destroy) {
        H2O.prototype.removeAnnotationMarkupAndUnlayered(annotation);
        H2O.prototype.manageLayers(annotation.id, 'deleted');
        $('span#annotation-bar-indicator-' + annotation.id + ',a#annotation-indicator-' + annotation.id).remove();
        return;
      }

      annotation.layers = $.parseJSON(annotation.layers);
      annotation.text = annotation.text;
      annotation.link = annotation.link;
      annotation.highlight_only = annotation.highlight_only;
      H2O.prototype.updateAnnotationMarkup(annotation);
      H2O.prototype.manageLayers(annotation, 'updated');
      H2O.prototype.setHighlights(annotation, false);
      collages.rehighlight();
    });

    this.annotator.subscribe("beforeAnnotationDeleted", function(annotation) {
      if(annotation.id !== undefined) {
        this.annotation_deleted_id = annotation.id;
      }
    });
    this.annotator.subscribe("annotationDeleted", function(annotation) {
      if(this.annotation_deleted_id !== null) {
        $('#annotation-indicator-' + this.annotation_deleted_id + ',span#annotation-bar-indicator-' + this.annotation_deleted_id + ',.layered-control-start-' + this.annotation_deleted_id + ',.layered-ellipsis-' + this.annotation_deleted_id + ',.layered-control-end-' + this.annotation_deleted_id).remove();
        H2O.prototype.manageLayers(this.annotation_deleted_id, 'deleted');
      }
      h2o_annotator.plugins.H2O.updateAllAnnotationIndicators();
    });
    this.annotator.editor.subscribe("hide", function() {
      if($('.annotator-editor').data('type') == 'annotate' && $('#show_comments .toggle-on').hasClass('active')) {
        $('span.edit-annotate, span.edit-annotate .icon-edit').show();  
      }
      if($('.annotator-editor').data('type') == 'link' && $('#show_links .toggle-on').hasClass('active')) {
        $('span.edit-link, span.edit-link .icon-edit').show();  
      }

      $('.annotator-listing li').hide();
      $('.annotator-checkbox input').prop('checked', false);
      $('.annotator-controls a, #h2o_delete').show();
      $('.annotator-editor').data('type', undefined);
      $('#link').val('');
      $('span#layer_error').remove();
    });

    /* Field management */
    this.annotator.editor.addField({
      id: 'show_annotation',
      type: 'checkbox',
      label: ''
    });
    this.annotator.editor.addField({
      id: 'link',
      type: 'input',
      label: 'http://'
    });
    var cat, color, highlight;
    for (cat in this.categories) {
      color = this.categories[cat];
      this.annotator.editor.addField({
        id: 'layer-' + collages.clean_layer(cat),
        type: 'checkbox',
        label: cat,
        value: cat
      });
    }
    this.layer_map = this.categories;

    for (highlight in this.highlights_only) {
      color = this.highlights_only[highlight];
      this.annotator.editor.addField({
        id: 'highlight-only-' + collages.clean_layer(color),
        type: 'checkbox2',
        label: '&nbsp;',
        value: color
      });
    }

    this.annotator.editor.addField({
      load: this.updateEditor
    });
    this.annotator.viewer.addField({
      load: this.updateViewer
    });
    this.annotator.editor.addField({
      id: 'new_layer',
      type: 'input',
      label: 'Enter Tag Name (optional)'
    });
    $.each(this.layer_map, function(layer, hex) {
      collages.set_highlights({ layer: layer, hex: hex });
    });
    $.each(this.highlights_only, function(i, highlight) {
      collages.set_highlights_for_highlight_only(highlight);
    });
  };

  H2O.prototype.resetAnnotationEditor = function(annotation) {
    $('.annotator-listing li').hide();
    $('#show_annotation').attr('checked', false);
    $('.annotator-controls a').show();
    $('#h2o_delete').show();
    $('.annotator-editor').data('type', undefined);
    $('#link').val('');
  };

  H2O.prototype.addAnnotationIndicator = function(annotation) {
    if((annotation.feedback || annotation.error) && !(h2o_annotator.plugins.H2O.can_edit || (annotation.user_id && annotation.user_id == h2o_annotator.options.user_id))) {
      return;
    } else if(annotation.discuss && (!h2o_annotator.plugins.H2O.can_discuss || !h2o_annotator.plugins.H2O.can_edit)) {
      return;
    }
    var first_highlight = $('.annotation-' + annotation.id + ':first');
    var last_highlight = $('.annotation-' + annotation.id + ':last');
    if(first_highlight.size() > 0) {
      var start_position = Math.round(first_highlight.position().top);
      var class_name = 'annotation-bar-indicator';
      var height = last_highlight.position().top + last_highlight.height() - start_position;
      $.each(annotation.layers, function(i, el) {
        class_name += ' annotation-bar-indicator-' + collages.clean_layer(el);
      });

      var found_position = false;
      while(!found_position) {
        found_position = true;
        $.each(h2o_annotator.plugins.H2O.annotation_indicator_map, function(i, j) {
          for(var i = j; i< j+27; i++) {
            if(start_position == i) {
              start_position += 27;
              found_position = false;
            }
          }
        });
      }
      h2o_annotator.plugins.H2O.annotation_indicator_map["a" + annotation.id] = start_position;

      $('.annotator-wrapper').append($('<span>').attr('data-id', annotation.id).addClass(class_name).attr('id', 'annotation-bar-indicator-' + annotation.id).css({ 'top' : start_position, 'height' : height, display: 'none' }));
      if(!annotation.hidden) {
        $('#annotation-bar-indicator-' + annotation.id).show();
      }

      if(annotation.hidden) {
        $('.annotator-wrapper').append($('<a>').attr('data-id', annotation.id).addClass('annotation-indicator icon icon-adder-show').attr('id', 'annotation-indicator-' + annotation.id).css({ 'top' : start_position, 'display': 'none' }));
        if($('#show_text_edits .toggle-inner .toggle-on').hasClass('active')) {
          $('.annotation-' + annotation.id).show();
          $('.annotation-' + annotation.id).parents('.original_content').show();
          $('.layered-control-start-' + annotation.id + ',.layered-control-end-' + annotation.id).css('display', 'inline-block');
          $('#layered-ellipsis-' + annotation.id).hide();
          h2o_annotator.plugins.H2O.updateAllAnnotationIndicators();
        }
      } else if(annotation.highlight_only !== null) {
        if(h2o_annotator.plugins.H2O.can_edit) {
          $('.annotator-wrapper').append($('<a>').attr('data-id', annotation.id).addClass('annotation-indicator icon icon-adder-highlight-only indicator-highlight-hex-' + annotation.highlight_only).attr('id', 'annotation-indicator-' + annotation.id).css({ 'top' : start_position, 'right' : -31 }));
        }
      } else if(annotation.link !== null) {
        var div = $('<div>').attr('data-id', annotation.id).addClass('annotation-indicator annotation-indicator-link').attr('id', 'annotation-indicator-' + annotation.id).css({ 'top': start_position });
        div.append($('<span>').addClass('icon icon-adder-link'));
        var html = '<a class="link" target="_blank" href="' + annotation.link + '">' + annotation.link + '</a>';
        if(!h2o_annotator.plugins.H2O.can_edit) {
          div.append($('<span>').addClass('readonly-link').html(html));
        } else {
          var text_node = $('<span>').addClass('edit-link').html(html);
          text_node.append($('<a>').attr('href', '#').addClass('icon icon-edit'));
          div.append(text_node);
          if($('#show_links .toggle-inner .toggle-on').hasClass('active')) {
            text_node.show();
          }
        }
        $('.annotator-wrapper').append(div);
      } else if(annotation.layers.length > 0) {
        var div_type = '<a>';
        if(h2o_annotator.plugins.H2O.can_edit) {
          div_type = '<span>';
        }
        var div = $(div_type).addClass('annotation-indicator annotation-indicator-highlights').attr('id', 'annotation-indicator-' + annotation.id).attr('data-id', annotation.id).css({ 'top': start_position, 'opacity': 0.0 });
        var clean_layer = collages.clean_layer(annotation.layers[0]);
        div.addClass('indicator-highlight-' + clean_layer).html(annotation.layers[0]);
        if(div_type == '<a>') {
          div.attr('href', '#');
        }
        $('.annotator-wrapper').append(div);
        div.css({ 'right': (div.width() + 17)*-1, 'opacity': 1.0 });
      } else if(annotation.error || annotation.discuss || annotation.feedback) {
        var type;
        if(annotation.error) {
          type = 'error';
        } else if(annotation.discuss) {
          type = 'discuss';
        } else {
          type = 'feedback';
        }
        var div = $('<div>').attr('data-id', annotation.id).addClass('annotation-indicator annotation-indicator-' + type).attr('id', 'annotation-indicator-' + annotation.id).css({ 'top': start_position });
        div.append($('<span>').addClass('icon icon-adder-' + type));
        if((h2o_annotator.plugins.H2O.can_edit || annotation.user_id == h2o_annotator.options.user_id) && (annotation.error || annotation.feedback)) {
          var text_node = $('<span>').addClass('delete-' + type).html(annotation.text);
          var explanation = type == 'error' ? 'Reported' : 'Sent';
          var attribution = annotation.user_id == h2o_annotator.options.user_id ? 'You' : '<a href="/users/' + annotation.user_id + '">' + (annotation.user_attribution ? annotation.user_attribution : 'Unamed User') + '</a>';
          text_node.append($('<span>').html(' (' + explanation + ' by: ' + attribution + ')'));
          text_node.append($('<a>').attr('href', '#').addClass('icon icon-delete'));
          div.append(text_node);
          if($('#show_comments .toggle-inner .toggle-on').hasClass('active')) {
            text_node.show();
          }
        } else {
          div.append($('<span>').addClass('readonly-' + type).html(annotation.text).show());
        }
        $('.annotator-wrapper').append(div);
      } else {
        var div = $('<div>').attr('data-id', annotation.id).addClass('annotation-indicator annotation-indicator-annotate').attr('id', 'annotation-indicator-' + annotation.id).css({ 'top': start_position });
        div.append($('<span>').addClass('icon icon-adder-annotate'));
        if(h2o_annotator.plugins.H2O.can_edit) {
          var text_node = $('<span>').addClass('edit-annotate').html(annotation.text);
          text_node.append($('<a>').attr('href', '#').addClass('icon icon-edit'));
          div.append(text_node);
          if($('#show_comments .toggle-inner .toggle-on').hasClass('active')) {
            text_node.show();
          }
        } else {
          div.append($('<span>').addClass('readonly-annotate').html(annotation.text));
        }
        $('.annotator-wrapper').append(div);
      }
    }
  };
  H2O.prototype.updateAllAnnotationIndicators = function() {
    h2o_annotator.plugins.H2O.annotation_indicator_map = {};
    $.each($('.annotation-bar-indicator').get().reverse(), function(i, el) {
      h2o_annotator.plugins.H2O.updateAnnotationIndicator($(el).data('id'));
    });
  };
  H2O.prototype.updateAnnotationIndicator = function(annotation_id) {
    var first_highlight = $('.annotation-' + annotation_id + ':first');
    var last_highlight = $('.annotation-' + annotation_id + ':last');
    if(first_highlight.size() > 0) {
      if($('.annotation-' + annotation_id + ':visible').size() == 0) {
        $('span#annotation-bar-indicator-' + annotation_id).css({ 'top' : 0, 'height': 0 }).hide();
        if($('#annotation-indicator-' + annotation_id).hasClass('icon-adder-show')) {
          $('#annotation-indicator-' + annotation_id).hide();
        }
      } else {
        var start_position = Math.round(first_highlight.position().top);
        var height = last_highlight.position().top + last_highlight.height() - start_position;
        $('span#annotation-bar-indicator-' + annotation_id).css({ 'top' : start_position, 'height' : height }).show();

        var found_position = false;
        while(!found_position) {
          found_position = true;
          $.each(h2o_annotator.plugins.H2O.annotation_indicator_map, function(i, j) {
            for(var i = j; i<j+27; i++) {
              if(start_position == i) {
                start_position += 27;
                found_position = false;
              }
            }
          });
        }
        h2o_annotator.plugins.H2O.annotation_indicator_map["a" + annotation_id] = start_position;
        $('#annotation-indicator-' + annotation_id).css({ 'top' : start_position }).show();
      }
    }
  };

  H2O.prototype.manageLayers = function(annotation, type) {
    if(type == 'created' || type == 'updated') {
      var modifying_layers = false;
      $.each(annotation.layers, function(i, layer) {
        var clean_layer = collages.clean_layer(layer);
        if($("#layers_highlights li[data-name='" + clean_layer + "']").size() == 0) {
          modifying_layers = true;
        }
      });
      if(annotation.highlight_only) {
        if($('#layers_highlights li.highlight_only_layer[data-hex=' + annotation.highlight_only + ']').size() == 0) {
          modifying_layers = true;
        }
      }

      if(modifying_layers) {
        h2o_annotator.editor.element.find('#new_layer').parent().remove();
        h2o_annotator.editor.fields.pop();

        $.each(annotation.layers, function(i, layer) {
          var clean_layer = collages.clean_layer(layer);

          if($("#layers_highlights li[data-name='" + clean_layer + "']").size() == 0) {
            h2o_annotator.editor.addField({
              id: 'layer-' + clean_layer,
              type: 'checkbox',
              label: layer,
              value: layer
            });
            
            //Manage li options
            var data = { hex: h2o_annotator.plugins.H2O.layer_map[layer], layer: layer, clean_layer: collages.clean_layer(layer) };
            var new_node = $(jQuery.mustache(layer_tools_highlights, data));
            new_node.appendTo($('#layers_highlights'));
  
            collages.turn_on_initial_highlight('name', clean_layer);
            collages.set_highlights(data);
          }
        });

        if(annotation.highlight_only) {
          h2o_annotator.editor.addField({
            id: 'highlight-only-' + annotation.highlight_only,
            type: 'checkbox2',
            label: '&nbsp;',
            value: annotation.highlight_only
          });

          //Manage li options
          var data = { hex: annotation.highlight_only };
          var new_node = $(jQuery.mustache(layer_tools_highlight_only, data));
          new_node.appendTo($('#layers_highlights'));
  
          collages.turn_on_initial_highlight('hex', annotation.highlight_only);
          collages.set_highlights_for_highlight_only(annotation.highlight_only);
        }

        h2o_annotator.editor.addField({
          id: 'new_layer',
          type: 'input',
          label: 'Enter Tag Name (optional)'
        });
        var hexes = collages.getHexes();
        hexes.insertAfter($('#new_layer')); 
        $('.annotator-listing li').hide();
      }
    }

    if(type == 'deleted' || type == 'updated') {
      $.each($('#layers_highlights li.user_layer'), function(i, el) {
        if(!(type == 'updated' && $(el).data('name') == collages.clean_layer(annotation.layers[0]))) {
          var clean_layer = collages.clean_layer($(el).data('name'));
          if($('.annotator-wrapper span.annotator-hl.layer-' + clean_layer).size() == 0) {
            var updated_fields = new Array();
            for(var _j = 0; _j < h2o_annotator.editor.fields.length; _j++) {
              if(h2o_annotator.editor.fields[_j].id != 'layer-' + clean_layer) {
                updated_fields.push(h2o_annotator.editor.fields[_j]);
              } else {
                h2o_annotator.editor.element.find('#layer-' + clean_layer).parent().remove();
              }
            }
            h2o_annotator.editor.fields = updated_fields;
            $(el).remove();
          }
        }
      });
      $.each($('#layers_highlights li.highlight_only_layer'), function(i, el) {
        if(!(type == 'updated' && $(el).data('hex') == annotation.highlight_only)) {
          var hex = $(el).data('hex');
          if($('.annotator-wrapper span.annotator-hl.layer-hex-' + hex).size() == 0) {
            var updated_fields = new Array();
            for(var _j = 0; _j < h2o_annotator.editor.fields.length; _j++) {
              if(h2o_annotator.editor.fields[_j].id != 'highlight-only-' + hex) {
                updated_fields.push(h2o_annotator.editor.fields[_j]);
              } else {
                h2o_annotator.editor.element.find('#highlight-only-' + hex).parent().remove();
              }
            }
            h2o_annotator.editor.fields = updated_fields;
            $(el).remove();
          }
        }
      });
      var updated_hexes = collages.getHexes();
      $('.hexes').replaceWith(updated_hexes);
    }
    return;
  };
  
  H2O.prototype.updateAnnotationMarkup = function(annotation) {
    if($('#annotation-indicator-' + annotation.id).hasClass('icon-adder-show')) {
      var clean_layer = collages.clean_layer(annotation.layers[0]);
      $('.layered-control-start-' + annotation.id + ',.layered-control-end-' + annotation.id).css('display', 'none');
      $('.layered-ellipsis-' + annotation.id).css('display', 'inline-block');
      $('.layered-control-start-' + annotation.id).attr('class', 'layered-control-start layered-control-start-' + annotation.id + ' ' + clean_layer);
      $('.layered-control-end-' + annotation.id).attr('class', 'layered-control-end layered-control-end-' + annotation.id + ' ' + clean_layer);
      $('.layered-ellipsis-' + annotation.id).attr('class', 'scale1-3 layered-ellipsis layered-ellipsis-' + annotation.id + ' layered-ellipsis-hidden ' + clean_layer);
      $('#annotation-indicator-' + annotation.id).css('display', 'none');
    } else if(annotation.text !== null && annotation.text != '') {
      $($('#annotation-indicator-' + annotation.id + ' .edit-annotate').contents()[0]).replaceWith(annotation.text);
    } else if(annotation.link !== null && annotation.link != '') {
      $('#annotation-indicator-' + annotation.id + ' .edit-link a.link').html(annotation.link).attr('href', annotation.link);
    } else if(annotation.highlight_only !== null && annotation.highlight_only !== undefined) {
      var class_string = 'annotator-hl annotation-' + annotation.id + ' layer-hex-' + annotation.highlight_only;
      if($("#layers_highlights li.highlight_only_layer[data-hex='" + annotation.highlight_only + "']").size() &&
        $("#layers_highlights li.highlight_only_layer[data-hex='" + annotation.highlight_only + "'] .toggle-on").hasClass('active')) {
        class_string += ' highlight-hex-' + annotation.highlight_only;
      }
      $('.annotation-' + annotation.id).attr('class', class_string);
      $('.layered-control-start-' + annotation.id).attr('class', 'layered-control-start layered-control-start-' + annotation.id + ' hex-' + annotation.highlight_only); 
      $('.layered-control-end-' + annotation.id).attr('class', 'layered-control-end layered-control-end-' + annotation.id + ' hex-' + annotation.highlight_only); 
      $('.layered-ellipsis-' + annotation.id).attr('class', 'layered-ellipsis layered-ellipsis-' + annotation.id + ' hex-' + annotation.highlight_only); 

      $('#annotation-indicator-' + annotation.id).attr('class', 'annotation-indicator icon icon-adder-highlight-only indicator-highlight-hex-' + annotation.highlight_only).html('').css({ 'right' : '-30px', 'opacity' : 0.5 });
    } else {
      var class_string = 'annotator-hl annotation-' + annotation.id;
      var clean_layer = collages.clean_layer(annotation.layers[0]);
      var div = $('#annotation-indicator-' + annotation.id);
      div.css({ opacity : 0.0 }).html(annotation.layers[0]).attr('class', 'annotation-indicator annotation-indicator-highlights indicator-highlight-' + clean_layer);
      if($("#layers_highlights li[data-name='" + clean_layer + "']").size() &&
        $("#layers_highlights li[data-name='" + clean_layer + "'] .toggle-on").hasClass('active')) {
        class_string += ' highlight-' + clean_layer;
      }
      var hex = h2o_annotator.plugins.H2O.layer_map[annotation.layers[0]];
      //div.append($('<a>').attr('href', '#').addClass('indicator-highlight-' + clean_layer).html(_l));
      $('.annotation-' + annotation.id).attr('class', class_string);
      div.css({ 'right': (div.width() + 17)*-1, 'opacity': 1.0 });
      $('.layered-control-start-' + annotation.id).attr('class', 'layered-control-start layered-control-start-' + annotation.id + ' ' + clean_layer);
      $('.layered-control-end-' + annotation.id).attr('class', 'layered-control-end layered-control-end-' + annotation.id + ' ' + clean_layer);
      $('.layered-ellipsis-' + annotation.id).attr('class', 'scale1-3 layered-ellipsis layered-ellipsis-' + annotation.id + ' layered-ellipsis-hidden ' + clean_layer);

      //if changed from highlight only
    }
  };

  H2O.prototype.annotationType = function(annotation) {
    if(annotation.error){
      return 'error';
    } else if(annotation.hidden) {
      return 'hidden';
    } else if(annotation.feedback) {
      return 'feedback';
    } else if(annotation.discussion) {
      return 'discussion';
    } else if(annotation.link !== null) {
      return 'link';
    } else if(annotation.highlight_only !== null) {
      return 'highlight';
    }
  };

  H2O.prototype.setLayeredBorders = function(annotation) {
    var _id = annotation.id;
    if(_id === undefined) {
      _id = 'noid';
    }
    var layer_class = '';
    if(annotation.layers !== undefined) {
      layer_class = annotation.layers[0] || '';
    }
    if(annotation.highlight_only !== null && annotation.highlight_only !== undefined) {
      layer_class = 'hex-' + annotation.highlight_only;
    }
    var start_node = $('.annotation-' + _id + ':first');
    var text = (annotation.text && annotation.text.length > 0) ? annotation.text : '...';
    var clean_layer = collages.clean_layer(layer_class);
    var fooble = _id + ' ' + clean_layer + '" data-layered="' + _id + '"';

    $('<a href="#" class="layered-control-start layered-control-start-' + fooble + ' data-type="' + H2O.prototype.annotationType(annotation) + '"></a>').insertBefore(start_node);
    $('<a href="#" class="scale1-3 layered-ellipsis layered-ellipsis-' + fooble + '>[' + text + ']</a>').insertBefore(start_node);
    var end_node = $('.annotation-' + _id + ':last');
    $('<a href="#" class="layered-control-end layered-control-end-' + fooble + ' data-type="' + H2O.prototype.annotationType(annotation) + '"></a>').insertAfter(end_node);

    $('.layered-ellipsis').off('click').on('click', function(e) {
      e.preventDefault();
      if(!!$('#print-options').length) {
        //Export doesn't need event handlers on things it will never display
        return;
      }
      var _id = $(this).data('layered');
      $('.annotation-' + _id).show().parents('.original_content').show();
      $('.layered-control-start-' + _id + ',.layered-control-end-' + _id).css('display', 'inline-block');
      $(this).hide();
      h2o_annotator.plugins.H2O.updateAllAnnotationIndicators();
    });
    $('.layered-control-start,.layered-control-end,.annotation-' + _id).off('click').on('click', function(e) {
      e.preventDefault();
      var _id = $(this).hasClass('annotation-hidden') ? $(this).data('annotation-id') : $(this).data('layered');
      var anno_nodes = $('.annotation-' + _id);
      anno_nodes.hide();
      $('.layered-control-start-' + _id + ',.layered-control-end-' + _id).hide();
      $('.layered-ellipsis-' + _id).css('display', 'inline-block');
      $('#annotation-indicator-' + _id).hide();
      anno_nodes.parents('.original_content').filter(':not(.original_content *):not(:has(.annotator-hl:visible,.layered-ellipsis:visible))').hide();
      h2o_annotator.plugins.H2O.updateAllAnnotationIndicators();
    });
  };

  H2O.prototype.setHighlights = function(annotation, created) {
    var h, _i, _len, _results;
    _results = [];
    var clean_layer;
    if(annotation.layers.length == 1) {
      clean_layer = collages.clean_layer(annotation.layers[0]);
    } else if(annotation.highlight_only !== null) {
      clean_layer = 'hex-' + annotation.highlight_only;
    }

    if(clean_layer !== undefined) {
      $.each(annotation._local.highlights, function(_i, h) {
        h = annotation._local.highlights[_i];
        _results.push(h.className = h.className + ' layer-' + clean_layer);
        if(created || $('li.user_layer[data-name="' + clean_layer + '"] .toggle-on').hasClass('active')) {
          _results.push(h.className = h.className + ' highlight-' + clean_layer);
        }
        if(created || $('li.highlight_only_layer[data-hex="' + clean_layer.replace(/hex-/, '') + '"] .toggle-on').hasClass('active')) {
          _results.push(h.className = h.className + ' highlight-' + clean_layer);
        } 
      });
    }
  };

  H2O.prototype.applyHiddenAnnotation = function(annotation) {
    console.log(annotation);
    //NOTE: hidden text annotations with large amounts of text can be very slow here.
    $('.layered-ellipsis-' + annotation.id).addClass('layered-ellipsis-hidden').css('display', 'inline-block');
    var anno_nodes = $('.annotation-' + annotation.id);
    anno_nodes.addClass('annotation-hidden').hide();
    var anno_nodes_oc_parents = anno_nodes.parents('.original_content');
    anno_nodes_oc_parents.filter(':not(.original_content *):not(:has(.annotator-hl:visible,.layered-ellipsis:visible))').hide();

    $.each(anno_nodes_oc_parents.filter(':not(.original_content *)'), function(i, j) {
      var j_node = $(j);
      var has_text_node = false;
      $.each(j_node.contents(), function(k, l) {
        if(l.nodeType == 3 && $(l).text() != ' ') {
          has_text_node = true;
          return;
        }
      });
      if(has_text_node) {
        j_node.show();
      }
    });

  };


  H2O.prototype.updateEditor = function(field, annotation) {
    $('.annotator-checkbox input').prop('checked', false);
    if(annotation.id !== undefined) {
      //annotation is not new
      $.each(annotation.layers, function(i, layer) {
        $('input#layer-' + collages.clean_layer(layer)).prop('checked', true);
      });
    } else {
      //annotation is new
      if(annotation.layer_hexes !== undefined) {
        $.each(annotation.layer_hexes, function(i, el) {
          $('input#layer-' + el.layer).prop('checked', true);
        });
      }
    }

    $(field).hide();
  };

  H2O.prototype.updateViewer = function(field, annotation) {
    $('.annotator-viewer').css({ 'opacity': 0.0 });
    var indicator = $('#annotation-indicator-' + annotation.id);
    
    if($('#print-options').size() > 0) {
      return;
    }

    if((indicator.hasClass('annotation-indicator-link') || indicator.hasClass('annotation-indicator-annotate') || indicator.hasClass('annotation-indicator-feedback') || indicator.hasClass('annotation-indicator-discuss') || indicator.hasClass('annotation-indicator-error'))
      && !$('#annotation-indicator-' + annotation.id + ' span:not(.icon)').is(':visible')) {
      $('.annotation-' + annotation.id).addClass('with_comment');
      indicator.addClass('was_hidden').css('opacity', 1.0);
      indicator.find('.icon-edit').hide();
      indicator.find('span:not(.icon)').show();
    }

    field = $(field);
    field.addClass('annotator-collage').hide();

    if(annotation.text != '') {
      $('.annotator-annotation > div').show(); 
    } else {
      $('.annotator-annotation > div').hide();
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
      if(annotation.layers !== undefined) {
        for(var _j = 0; _j < annotation.layers.length; _j++) {
          layers.push(annotation.layers[_j].name);
        }
      }
      var formatted_annotation = { "id" : annotation.id,
        "text" : annotation.annotation,
        "ranges": ranges,
        "layers": layers,
        "cloned": annotation.cloned,
        "link" : annotation.link,
        "hidden" : annotation.hidden,
        "error" : annotation.error,
        "discuss" : annotation.discussion,
        "feedback" : annotation.feedback,
        "highlight_only": annotation.highlight_only,
        "user_id" : annotation.user_id,
        "user_attribution" : annotation.user_attribution
      };
      formatted_annotation.ranges = ranges;
      formatted_annotations.push(formatted_annotation);
    });

    return formatted_annotations;
  };

  H2O.prototype.loadAnnotations = function(c_id, current_annotations, page_load) {
    if(page_load) {
      this.annotated_item_id = c_id;
    }

    var data = this.format_annotations(current_annotations);
    h2o_annotator.loadAnnotations(data);
  }
 
  H2O.prototype.removeAnnotationMarkupAndUnlayered = function(annotation) {
    h2o_annotator.publish('beforeAnnotationDeleted', [annotation]);
    this.removeAnnotationMarkup(annotation);
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
