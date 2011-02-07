jQuery.extend({

  addLayerToCookie: function(cookieName,layerId){
    var currentVals = jQuery.unserializeHash(jQuery.cookie(cookieName));
    currentVals[layerId] = 1;
    var cookieVal = jQuery.serializeHash(currentVals);
    jQuery.cookie(cookieName, cookieVal, {
      expires: 365
    });
  },

  submitAnnotation: function(){
    var collageId = jQuery('.collage-id').attr('id').split('-')[1];
    jQuery('#annotation-form form').ajaxSubmit({
      error: function(xhr){
        jQuery('#spinner_block').hide();
        jQuery('#new-annotation-error').show().append(xhr.responseText);
      },
      beforeSend: function(){
        jQuery('#spinner_block').show();
        jQuery('div.ajax-error').html('').hide();
        jQuery('#new-annotation-error').html('').hide();
        jQuery.showPleaseWait();
      },
      success: function(response){
        jQuery('#spinner_block').hide();
        jQuery.cookie('layer-names', jQuery('#annotation_layer_list').val(), {
          expires: 365
        });
        jQuery('#annotation-form').dialog('close');
        document.location = jQuery.rootPath() + 'collages/' + collageId;
      }
    });
  },

  removeLayerFromCookie: function(cookieName,layerId){
    var currentVals = jQuery.unserializeHash(jQuery.cookie(cookieName));
    delete currentVals[layerId];
    var cookieVal = jQuery.serializeHash(currentVals);
    jQuery.cookie(cookieName,cookieVal,{
      expires: 365
    });
  },

  annotateRange: function(obj,activeId,aIndex){
    var start = obj.annotation_start.substring(1);
    var end = obj.annotation_end.substring(1);
    var points = [parseInt(start), parseInt(end)];
    var elStart = points[0];
    var elEnd = points[1];
    var i = 0;
    var ids = [];
    for(i = elStart; i <= elEnd; i++){
      ids.push('#t' + i);
    }
    var activeLayers = jQuery.unserializeHash(jQuery.cookie('active-layer-ids'));
    var layerNames = [];
    var lastLayerId = 0;
    var layerOutput = '';
    jQuery(obj.layers).each(function(){
      layerNames.push(this.name);
      layerOutput += '<span class="ltag c' + (this.id % 10) + '">' + this.name + '</span>';
      lastLayerId = this.id;
    });

    var detailNode = jQuery('<span class="annotation-control annotation-start ' + 'c' + (lastLayerId % 10) + ' annotation-control-' + obj.id + '"></span>');
    jQuery(detailNode).html('<a href="#" class="close-annotation-details ann-close-' + obj.id + '"><img src="' + jQuery.rootPath() + 'images/elements/close.gif" /></a>' + layerOutput + '<div class="clear"></div>' + ((obj.annotation_word_count > 0) ? '<div class="annotation-content">' + obj.formatted_annotation_content + '</div>' : '' ) + '<div class="more"><a href="#" class="ann-details-' + obj.id +'">more &raquo;</a></div>' + ' <span class="print-inline">#' + obj.id + '</span>');

    var startArrow = jQuery('<span id="annotation-control-' + obj.id +'" class="arr rc' + (lastLayerId % 10) + '"></span>');
    jQuery("#t" + elStart).before(detailNode, startArrow);

    var endArrow = jQuery('<span id="annotation-control-' + obj.id +'" class="arr rc' + (lastLayerId % 10) + '"></span>');
    jQuery("#t" + elEnd).after(endArrow);

    var idList = ids.join(',');

    jQuery.annotationArrow(startArrow,obj,aIndex,'start');
    jQuery.annotationArrow(endArrow,obj,aIndex,'end');

    if(obj.id == activeId){
      jQuery("#annotation-control-" + obj.id).mouseenter();
      //console.log('active!');
    }
  },

  annotationArrow: function(arr,obj,aIndex,arrowType){
    if(true){
      // do something crippled and stupid here for IE.
      if (arrowType == 'start'){
        jQuery(arr).html(((obj.annotation_word_count > 0) ? ('<span class="arrbox">' + aIndex + '</span>') : '') + '&#9658;' );
      } else {
        jQuery(arr).html('&#9668;' + ((obj.annotation_word_count > 0) ? ('<span class="arrbox">' + aIndex + '</span>') : ''));
      }
    } else {
      var canvas = document.createElement('canvas');
      var canvasWidth = (obj.annotation_word_count > 0) ? 60 : 18;
      jQuery(canvas).attr('width',canvasWidth).attr('height',18).appendTo(jQuery(arr)); 
      var ctx = canvas.getContext('2d');
      ctx.fillStyle = jQuery(arr).css('color');
      ctx.strokeStyle = jQuery(arr).css('color');
      ctx.textAlign = 'center';
      ctx.font = '12px Arial';
      ctx.beginPath();
      if(arrowType == 'start'){
        ctx.moveTo(canvasWidth - 18,0);
        ctx.lineTo(canvasWidth,9);
        ctx.lineTo(canvasWidth - 18,18);
        ctx.fill();
        if(obj.annotation_word_count > 0){
          ctx.strokeRect(0,0,canvasWidth - 18,18);
          ctx.fillText(aIndex,18,14);
        }
      } else {
        ctx.moveTo(18,0);
        ctx.lineTo(0,9);
        ctx.lineTo(18,18);
        ctx.fill();
        if(obj.annotation_word_count > 0){
          ctx.strokeRect(18,0,42,18);
          ctx.fillText(aIndex,36,14);
        }
      }
    }

    var btOptions = {
      trigger: 'none',
      contentSelector: "jQuery('.annotation-control-" + obj.id + "').html()",
      fill: '#F7F7F7',
      clickAnywhereToClose: false,
      strokeStyle: '#B7B7B7', 
      spikeLength: 20, 
      shadow: true,
      spikeGirth: 10,
      width: ((obj.annotation_word_count > 0) ? 300 : 150),
      padding: 8, 
      cornerRadius: 5,
      wrapperzIndex: 900,
      boxzIndex: 901,
      textzIndex: 902,
      positions: ['top'],
      cssStyles: { fontSize: '11px' },
      postShow: function(box){
        jQuery('.ann-details-' + obj.id).click(function(e){
          jQuery.annotationButton(e,obj.id);
        });
        jQuery('.ann-close-' + obj.id).click(function(e){
          e.preventDefault();
          jQuery(arr).btOff();
        });
      }
    };

    jQuery(arr).click(function(e){
      e.preventDefault();
      jQuery.toggleAnnotation(obj, undefined, jQuery.blockLevels());
    });

    jQuery(arr).hoverIntent({
      over: function(e){
        jQuery(arr).bt(btOptions);
        jQuery(arr).btOn();
        jQuery('.a' + obj.id).addClass('highlight');
      },
      timeout: 3000,
      out: function(e){
        jQuery('.a' + obj.id).removeClass('highlight');
        if(obj.annotation_word_count == 0){
          // If an annotation doesn't have text, close it automatically.
          jQuery(arr).btOff();
        }
      }
    });
  },

  blockLevels: function(){
    // from: http://www.cs.sfu.ca/CC/165/sbrown1/wdgxhtml10/block.html
    return {ADDRESS: true, BLOCKQUOTE: true, CENTER: true, DIR: true, DIV: true, DL: true, FIELDSET: true, FORM: true, H1: true, H2: true, H3: true, H4: true, H5: true, H6: true, HR: true, ISINDEX: true, MENU:true , NOFRAMES: true, NOSCRIPT: true, OL: true , P: true , PRE: true , TABLE: true, UL: true, DD: true, DT: true, FRAMESET: true, LI: true, TBODY: true, TD: true, TFOOT: true, TH: true, THEAD: true, TR: true};
  },

  toggleAnnotation: function(obj, displaySelector, blockLevels){
    var displayVal = '';

    if(typeof(displaySelector) === 'undefined'){
      displayVal = (jQuery('.a' + obj.id + ':visible').length > 0) ? 'none' : '';
    } else {
      displayVal = (displaySelector == 'on') ? '' : 'none';
    }

    var blockLevelElements = [];
    jQuery('.a' + obj.id).each(function(){
      jQuery(this).css('display',displayVal);

      var parentNode = jQuery(this).parent().get(0);
      var sibling = jQuery(this).next().get(0);

      //      console.log('Parent Display: ',jQuery(parentNode).css('display'), 'Parent Tag Name: ', jQuery(parentNode)[0].tagName, 'Sibling Display: ', jQuery(sibling).css('display'), 'Sibling Tag Name: ', (typesibling) ? jQuery(sibling)[0].tagName : null);
      if( blockLevels[parentNode.tagName] == true){
        blockLevelElements.push(parentNode);
      }
      if(displayVal == 'none'){
        if(sibling != undefined && sibling.tagName == 'BR'){
          jQuery(sibling).hide();
        }
      } else {
        if(sibling != undefined && sibling.tagName == 'BR'){
          jQuery(sibling).show();
        }
      }
    });

    blockLevelElements = jQuery.unique(blockLevelElements);
    jQuery(blockLevelElements).each(function(index,el){
      if(displayVal == 'none'){
        jQuery(el).css('display','inline');
      } else {
        jQuery(el).css('display','block');
      }
    });

  },

  toggleAnnotationOld: function(obj,displaySelector,fixArrows){
    var displayVal = '';
    if(typeof(displaySelector) === 'undefined'){
      displayVal = (jQuery('.a' + obj.id + ':visible').length > 0) ? 'none' : '';
    } else {
      displayVal = (displaySelector == 'on') ? '' : 'none';
    }
    var node = jQuery('#' + obj.annotation_start);
    var endId = obj.annotation_end;
    //So what we want to do is get parents up to #annotatable-content for the start node.
    //Then - for the end node, get its parents up to #annotatable-content.
    //* If the start and end node have the same parent, just the hide content between them.
    //* If they are different, hide from the start to the end of its parent.
    //* Then iterate from the start node's parent to the end node's parent, hiding nodes along the way. Then hide from the end node to the start of its parent.
    var startNode = jQuery('#' + obj.annotation_start);
    var endNode = jQuery('#' + obj.annotation_end);

    var startRootParent = jQuery(startNode).parentsUntil('#annotatable-content').last();
    var endRootParent = jQuery(endNode).parentsUntil('#annotatable-content').last();

    console.log('Start root: ', startRootParent, typeof(jQuery(startRootParent)[0]),'End Root: ', endRootParent, typeof(jQuery(endRootParent)[0]));

    if(jQuery(endRootParent)[0] == jQuery(startRootParent)[0]){
      console.log('start and end parent nodes are the same');
      // start and end parents are the same, which could be an orphaned start and end context.
      //      jQuery(startNode).nextUntil('#' + obj.annotation_end).filter(':not(.arr)').css('display',displayVal);
      // So this doesn't recurse into block level elements, meaning arrows get hidden when they shouldn't. It probably makes sense to write a generic iterator that will find all arrow nodes in the affected range and show them. 
      jQuery(startNode).nextAll().each(function(index,el){
        if (el === jQuery(endNode)[0]){
          return false;
        } else {
          jQuery(el).filter(':not(.arr)').css('display',displayVal);
        }
      });
    } else if(typeof(jQuery(startRootParent)[0]) === 'undefined' && typeof(jQuery(endRootParent)[0]) === 'object'){
      console.log("There's no start parent node but a valid end parent node");
      //Hide from the endNode to the beginning of its parent.
      //And then from the startNode to the end root parent node
      jQuery(endNode).prevUntil().filter(':not(.arr)').css('display',displayVal);
      jQuery(startNode).nextAll().each(function(index,el){
        if (el === jQuery(endRootParent)[0]){
          return false;
        } else {
          jQuery(el).filter(':not(.arr)').css('display',displayVal);
        }
      });
    } else if(typeof(jQuery(startRootParent)[0]) === 'object' && typeof(jQuery(endRootParent)[0]) === 'undefined'){
      console.log("There's a valid start parent node but no end parent node");
      // Hide from the start node until the end of it's parent.
      jQuery(startNode).nextUntil().filter(':not(.arr)').css('display',displayVal);
      // And then from the endNode to the start parent node.
      jQuery(endNode).prevAll().each(function(index,el){
        if (el === jQuery(startRootParent)[0]){
          return false;
        } else {
          jQuery(el).filter(':not(.arr)').css('display',displayVal);
        }
      });
    } else if(typeof(jQuery(startRootParent)[0]) === 'undefined' && typeof(jQuery(endRootParent)[0]) === 'undefined'){
      //Both nodes start and end with orphan text nodes.
      console.log("there isn't a valid start or end parent node");


    } else {
      console.log('start and end are valid nodes and ARE NOT the same');
      // start and end rootNodes AREN'T the same and are valid nodes nested under #annotatable-content
      // Iterate over the nodes between startRootParent and endRootParent, hiding them.
      // Then hide the nodes from the startNode to the end of its parent, and the nodes from the endNode to the beginning of its parent.

      jQuery(startRootParent).nextAll().each(function(index,el){
        if (el === jQuery(endRootParent)[0]){
          return false;
        } else {
          jQuery(el).filter(':not(.arr)').css('display',displayVal);
        }
      });

//      jQuery(startRootParent).children().css('display',displayVal);

      jQuery(startNode).nextUntil().filter(':not(.arr)').css('display',displayVal);
      jQuery(endNode).prevUntil().filter(':not(.arr)').css('display',displayVal);
    }
    jQuery(startNode).css('display',displayVal);
    jQuery(endNode).css('display',displayVal);
    if(fixArrows == true && displayVal == 'none'){
      console.log('fixing arrows');
      jQuery.fixArrows();
    }
  },

  annotationButton: function(e,annotationId){
    e.preventDefault();
    var collageId = jQuery('.collage-id').attr('id').split('-')[1];
    if(jQuery('#annotation-details-' + annotationId).length == 0){
      jQuery.ajax({
        type: 'GET',
        cache: false,
        url: jQuery.rootPath() + 'annotations/' + annotationId,
        beforeSend: function(){
          jQuery('#spinner_block').show();
          jQuery('div.ajax-error').html('').hide();
        },
        error: function(xhr){
          jQuery('#spinner_block').hide();
          jQuery('div.ajax-error').show().append(xhr.responseText);
        },
        success: function(html){
          // Set up the annotation node to be loaded into a dialog
          jQuery('#spinner_block').hide();
          var node = jQuery(html);
          jQuery('body').append(node);
          var dialog = jQuery('#annotation-details-' + annotationId).dialog({
            height: 500,
            title: 'Annotation Details',
            width: 600,
            position: [e.clientX,e.clientY - 330],
            buttons: {
              Close: function(){
                jQuery(this).dialog('close');
              },
              Delete: function(){
                if(confirm('Are you sure?')){
                  jQuery.ajax({
                    cache: false,
                    type: 'POST',
                    data: {
                      '_method': 'delete'
                    },
                    url: jQuery.rootPath() + 'annotations/destroy/' + annotationId,
                    beforeSend: function(){
                      jQuery('#spinner_block').show();
                      jQuery.showPleaseWait();
                    },
                    error: function(xhr){
                      jQuery('#spinner_block').hide();
                      jQuery('div.ajax-error').show().append(xhr.responseText);
                    },
                    success: function(response){
                      jQuery('#annotation-details-' + annotationId).dialog('close');
                      document.location = jQuery.rootPath() + 'collages/' + collageId;
                    },
                    complete: function(){
                      jQuery('#please-wait').dialog('close');
                    }
                  });
                }
              },
              Edit: function(){
                jQuery(this).dialog('close');
                jQuery.ajax({
                  type: 'GET',
                  cache: false,
                  url: jQuery.rootPath() + 'annotations/edit/' + annotationId,
                  beforeSend: function(){
                    jQuery('#spinner_block').show();
                    jQuery('#new-annotation-error').html('').hide();
                  },
                  error: function(xhr){
                    jQuery('#spinner_block').hide();
                    jQuery('#new-annotation-error').show().append(xhr.responseText);
                  },
                  success: function(html){
                    jQuery('#spinner_block').hide();
                    jQuery('#annotation-form').html(html);
                    jQuery.updateAnnotationPreview(collageId);
                    jQuery('#annotation-form').dialog({
                      bgiframe: true,
                      minWidth: 950,
                      width: 950,
                      modal: true,
                      title: 'Edit Annotation',
                      buttons: {
                        'Save': function(){
                          jQuery.submitAnnotation();
                        },
                        Cancel: function(){
                          jQuery('#new-annotation-error').html('').hide();
                          jQuery(this).dialog('close');
                        }
                      }
                    });
                    jQuery("#annotation_annotation").markItUp(myTextileSettings);

                    /*                    jQuery(document).bind('keypress','ctrl+shift+k',
                      function(e){
                      alert('pressed!');
                      jQuery.submitAnnotation();
                      }
                      ); */
                      jQuery('#annotation_layer_list').keypress(function(e){
                        if(e.keyCode == '13'){
                          e.preventDefault();
                          jQuery.submitAnnotation();
                        }
                      });
                  }
                });
              }
            }
          });

          jQuery('#annotation-tabs-' + annotationId).tabs();
          // Wipe out edit buttons if not owner.
          if(jQuery('#is_owner').html() != 'true'){
            jQuery('#annotation-details-' + annotationId).dialog('option','buttons',{
              Close: function(){
                jQuery(this).dialog('close');
              }
            });
          }
        }
      });
    } else {
      jQuery('#annotation-details-' + annotationId).dialog('open');
    }
  },

  showPleaseWait: function(){
    jQuery('#please-wait').dialog({
      closeOnEscape: false,
      draggable: false,
      modal: true,
      resizable: false,
      autoOpen: true
    });
  },

  hideEmptyElements: function(){
    // So - as brute force as this would appear, this seems to represent the best compromise between performance and cross-browser compatibility.
    // FIXME! dammit.
  //  jQuery('#annotatable-content tt:hidden').remove();
    //jQuery('#annotatable-content center, #annotatable-content p, #annotatable-content li, #annotatable-content ul, #annotatable-content blockquote, #annotatable-content ol, #annotatable-content h1').filter(function(){
      jQuery('#annotatable-content').find('center,p,li,ul,blockquote,ol,h1,h2,h3,h4,h5').filter(function(){
        var text = jQuery(this).text();
        var collapsedText = jQuery.trim11(text);
        //        if(collapsedText.length > 0){
          //          console.log('|' + escape(text) + '|')
          //        }
          return (collapsedText.length == 0);
      }).remove();
  },

  initializeAnnotations: function(){
    // This iterates through the annotations on this collage and emits the controls.
    var collageId = jQuery('.collage-id').attr('id').split('-')[1];
    jQuery.ajax({
      type: 'GET',
      url: jQuery.rootPath() + 'collages/annotations/' + collageId,
      dataType: 'json',
      cache: false,
      beforeSend: function(){
        jQuery('#spinner_block').show();
        jQuery.showPleaseWait();
        jQuery('div.ajax-error').html('').hide();
      },
      success: function(json){
        var aIndex = 1;
        //stash for later
        jQuery('body').data('annotation_objects',json);
        jQuery(json).each(function(){
          var activeId = false;
          if(window.location.hash){
            activeId = window.location.hash.split('#')[1];
          }
          jQuery.annotateRange(this.annotation,activeId,aIndex);
          if(this.annotation.annotation_word_count > 0){
            aIndex++;
          }
        });
        jQuery.observeWords();
        jQuery.hideEmptyElements();
        jQuery('#spinner_block').hide();
      },
      complete: function(){
        jQuery('#please-wait').dialog('close');
      },
      error: function(xhr){
        jQuery('#spinner_block').hide();
        jQuery('div.ajax-error').show().append(xhr.responseText);
      }

    });
  },

  observeLayers: function(){
    var collageId = jQuery('.collage-id').attr('id').split('-')[1];
    jQuery('.layer-control').click(function(e){
      var layerId = jQuery(this).attr('id').split('-')[2];
      if(jQuery('#layer-checkbox-' + layerId).is(':checked')){
        // Set the name and id of the active layers.
        jQuery.addLayerToCookie('active-layer-ids',layerId);
      } else {
        jQuery.removeLayerFromCookie('active-layer-ids',layerId);
      }
    });
  },

  updateCollagePreview: function(){
    jQuery("#collage_description").observeField(5,function(){
      jQuery.ajax({
        cache: false,
        type: 'POST',
        url: jQuery.rootPath() + 'collages/description_preview',
        data: {
          preview: jQuery('#collage_description').val()
        },
        success: function(html){
          jQuery('#collage_preview').html(html);
        }
      });
    });
  },

  updateAnnotationPreview: function(collageId){
    jQuery("#annotation_annotation").observeField(5,function(){
      jQuery.ajax({
        cache: false,
        type: 'POST',
        url: jQuery.rootPath() + 'annotations/annotation_preview',
        data: {
          preview: jQuery('#annotation_annotation').val(),
          collage_id: collageId
        },
        success: function(html){
          jQuery('#annotation_preview').html(html);
        }
      });
    });
  },

  wordEvent: function(e){
    if(e.type == 'mouseover'){
      jQuery(this).addClass('annotation_start_highlight')
    }
    if(e.type == 'mouseout'){
      jQuery(this).removeClass('annotation_start_highlight');
    } else if(e.type == 'click'){
      e.preventDefault();
      if(jQuery('#new-annotation-start').html().length > 0){
        // Set end point and annotate.
        jQuery('#new-annotation-end').html(jQuery(this).attr('id'));
        var collageId = jQuery('.collage-id').attr('id').split('-')[1];
        jQuery('#annotation-form').dialog({
          bgiframe: true,
          autoOpen: false,
          minWidth: 950,
          width: 950,
          modal: true,
          title: 'New Annotation',
          buttons: {
            'Save': function(){
              jQuery.submitAnnotation();
            },
            'Cancel': function(){
              jQuery('#new-annotation-error').html('').hide();
              jQuery(this).dialog('close');
            }
          }
        });
        jQuery('#' + jQuery('#new-annotation-start').html()).btOff();
        e.preventDefault();
        jQuery.ajax({
          type: 'GET',
          url: jQuery.rootPath() + 'annotations/new',
          data: {
            collage_id: collageId,
            annotation_start: jQuery('#new-annotation-start').html(),
            annotation_end: jQuery('#new-annotation-end').html()
          },
          cache: false,
          beforeSend: function(){
            jQuery('#spinner_block').show();
            jQuery('div.ajax-error').html('').hide();
          },
          success: function(html){
            jQuery('#spinner_block').hide();
            jQuery('#annotation-form').html(html);
            jQuery('#annotation-form').dialog('open');
            jQuery("#annotation_annotation").markItUp(myTextileSettings);
            /*            jQuery('#annotation_annotation').bind('keypress','alt+k',function(e){
              alert('pressed!');
              jQuery.submitAnnotation()
              }); */
              jQuery('#annotation_layer_list').keypress(function(e){
                if(e.keyCode == '13'){
                  e.preventDefault();
                  jQuery.submitAnnotation();
                }
              });
              jQuery.updateAnnotationPreview(collageId);
              if(jQuery('#annotation_layer_list').val() == ''){
                jQuery('#annotation_layer_list').val(jQuery.cookie('layer-names'));
              }
          },
          error: function(xhr){
            jQuery('#spinner_block').hide();
            jQuery('div.ajax-error').show().append(xhr.responseText);
          }
        });
        jQuery('#new-annotation-start').html('');
        jQuery('#new-annotation-end').html('');
      } else {
        // Set start point
        jQuery('#' + jQuery(this).attr('id')).bt({
          trigger: 'none',
          contentSelector: 'jQuery("#annotation-start-marker")',
          fill: '#F7F7F7',
          positions: ['top','most'],
          active_class: 'annotation_start_highlight',
          clickAnywhereToClose: false,
          closeWhenOthersOpen: true
        });
        jQuery('#' + jQuery(this).attr('id')).btOn();
        jQuery('#new-annotation-start').html(jQuery(this).attr('id'));
      }
    }
  },

  observeWords: function(){
    // This is a significant burden in that it binds to every "word node" on the page, so running it must
    // align with the rights a user has to this collage, otherwise we're just wasting cpu cycles. Also
    // the controller enforces privs - so feel free to fiddle with the DOM, it won't get you anywhere.
    // jQuery('tt:visible') as a query is much less efficient - unfortunately.

    if(jQuery('#is_owner').html() == 'true'){
      jQuery('tt').bind('mouseover mouseout click', jQuery.wordEvent);
    }
  }

});

jQuery(document).ready(function(){
  jQuery('.per-page-selector').change(function(){
    jQuery.cookie('per_page', jQuery(this).val(), {
      expires: 365
    });
    document.location = document.location;
  });
  jQuery('.per-page-selector').val(jQuery.cookie('per_page'));
  jQuery('.tablesorter').tablesorter();
  jQuery('.button').button();
  jQuery('#collage_submit').button({
    icons: {
      primary: 'ui-icon-circle-plus'
    }
  });
  if(jQuery('#collage_description').length > 0){
    jQuery("#collage_description").markItUp(myTextileSettings);
    jQuery.updateCollagePreview();
  }
  jQuery("#annotation_annotation").markItUp(myTextileSettings);

  jQuery.observeToolbar();
  jQuery.observeMetadataForm();

  if(jQuery('.just_born').length > 0){
    // New collage. Deactivate control.
    jQuery.cookie('hide-non-annotated-text', null);
  }

  if(jQuery.cookie('hide-non-annotated-text') == 'hide'){
    jQuery('#hide-non-annotated-text').attr('checked',true);
  }

  jQuery('#hide-non-annotated-text').click(function(e){
    if(jQuery.cookie('hide-non-annotated-text') == 'hide'){
      jQuery.cookie('hide-non-annotated-text',null);
      jQuery('#hide-non-annotated-text').attr('checked',false);
    } else {
      jQuery.cookie('hide-non-annotated-text','hide',{
        expires: 365
      });
      jQuery('#hide-non-annotated-text').attr('checked',true);
    }
  });

  jQuery('a#cancel-annotation').click(function(e){
    e.preventDefault();
    // close tip.
    jQuery('#' + jQuery('#new-annotation-start').html()).btOff();
    jQuery('#new-annotation-start').html('');
    jQuery('#new-annotation-end').html('');
  });

  if(jQuery('.collage-id').length > 0){
    jQuery.observeLayers();
    jQuery.initializeAnnotations();

    jQuery('#view-layer-list .layer-control').click(function(e){
      e.preventDefault();
      var layerId = jQuery(this).attr('id').split(/-/)[2];
      var spinner = jQuery('#layer-spinner-' + layerId);
      spinner.queue(function(){
        jQuery(this).show();
        jQuery(this).delay(250);
        jQuery(this).dequeue();
      });
      // Update indicator
      if(jQuery('#layer-indicator-' + layerId).html() == 'on'){
        spinner.queue(function(){
          var annotations = jQuery('body').data('annotation_objects');
          var blockLevels = jQuery.blockLevels();
          jQuery(annotations).each(function(i,ann){
            jQuery(ann.annotation.layers).each(function(i,layer){
              //              console.log(layer.id);
              if(layer.id == layerId){
                jQuery.toggleAnnotation(ann.annotation,'off',blockLevels);
              }
            });
          });
          jQuery(this).dequeue();
        });
        spinner.queue(function(){
          jQuery('#layer-indicator-' + layerId).html('off').addClass('off');
          jQuery(this).dequeue();
        });
      } else {
        spinner.queue(function(){
          var annotations = jQuery('body').data('annotation_objects');
          var blockLevels = jQuery.blockLevels();
          jQuery(annotations).each(function(i,ann){
            jQuery(ann.annotation.layers).each(function(i,layer){
              if(layer.id == layerId){
                jQuery.toggleAnnotation(ann.annotation,'on',blockLevels);
              }
            });
          });
          jQuery(this).dequeue();
        });
        spinner.queue(function(){
          jQuery('#layer-indicator-' + layerId).html('on').removeClass('off');
          jQuery(this).dequeue();
        });
      }
      spinner.queue(function(){
        jQuery(this).hide();
        jQuery(this).dequeue();
      });
    });

    jQuery('#view-layer-list .layer-control, #view-layer-list .layer-indicator, #view-layer-list .layer, #toggle-unlayered-text, .unlayered').mouseover(function(e){
      e.preventDefault();
      jQuery(this).css('cursor','pointer');
    });

    jQuery('#toggle-unlayered-text').click(function(e){
      e.preventDefault();
      var spinner = jQuery('#unlayered-spinner');
      spinner.queue(function(){
        jQuery(this).show();
        jQuery(this).delay(250);
        jQuery(this).dequeue();
      });
      if(jQuery('#unlayered-text-indicator').html() == 'on'){
        spinner.queue(function(){
          jQuery('#annotatable-content tt:not(.a)').css('display','none');
          jQuery(this).dequeue();
        });
        spinner.queue(function(){
          jQuery('#unlayered-text-indicator').html('off').addClass('off');
          jQuery(this).dequeue();
        });
      } else {
        spinner.queue(function(){
          jQuery('#annotatable-content tt:not(.a)').css('display','');
          jQuery(this).dequeue();
        });
        spinner.queue(function(){
          jQuery('#unlayered-text-indicator').html('on').removeClass('off');
          jQuery(this).dequeue();
        });
      }
      spinner.queue(function(){
        jQuery(this).hide();
        jQuery(this).dequeue();
      });
    });
    
    jQuery('.collapsible').bind({
      click: function(e){
        e.preventDefault();
        // get the second class right after .collapsible
        var targetClass = jQuery(this).attr('class').split(/\s+/)[1];
        if(jQuery('.' + targetClass + '-target').is(':visible')){
          jQuery(this).html(jQuery(this).html().replace('▼','▶'));
          jQuery('.' + targetClass + '-target').hide('fast');
        } else {
          jQuery(this).html(jQuery(this).html().replace('▶','▼'));
          jQuery('.' + targetClass + '-target').show('fast');
        }
      },
      mouseover: function(e){
        e.preventDefault();
        jQuery(this).css('cursor','pointer');
      }    
    });

    jQuery(".tagging-autofill-layers").live('click',function(){
      jQuery(this).tagSuggest({
        url: jQuery.rootPath() + 'annotations/autocomplete_layers',
        separator: ', ',
        delay: 500
      });
    });
  }
});
