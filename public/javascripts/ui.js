$.noConflict();

jQuery.extend({
  	classType: function() {
		return jQuery('body').attr('id').replace(/^b/, '');
	},
    rootPath: function(){
      return '/';
    },

	observeTabDisplay: function(region) {
		jQuery(region + ' .link-add a').click(function() {
			var element = jQuery(this);
			var position = element.offset();
			var results_posn = jQuery('.popup').parent().offset();
			var left = position.left - results_posn.left;
			var current_id = element.data('item_id');
			jQuery('.bookmark-this').attr('href', '/bookmark_item/' + element.data('bookmarktype'));
			var popup = jQuery('.popup');
			var last_id = popup.data('item_id');
			if(last_id) {
				popup.removeData('item_id').fadeOut(100, function() {
					if(current_id != last_id) {
						popup.css({ top: position.top + 24, left: left }).fadeIn(100).data('item_id', current_id);
					}
				});
			} else {
				popup.css({ top: position.top + 24, left: left }).fadeIn(100).data('item_id', current_id);
			}
			return false;
		});
	},
    observePagination: function(){
		jQuery('.pagination a').click(function(e){
      
	  		e.preventDefault();
      		jQuery.ajax({
        		type: 'GET',
        		dataType: 'html',
                data: { 'is_pagination' : 1 },
        		url: jQuery(this).attr('href'),
                beforeSend: function(){
               		jQuery.showGlobalSpinnerNode();
               	},
               	error: function(xhr){
               		jQuery.hideGlobalSpinnerNode();
				},
        		success: function(html){
               		jQuery.hideGlobalSpinnerNode();
					var region = '#all_' + jQuery.classType();
					jQuery(region).html(html);
					jQuery('.pagination').html(jQuery(region + ' #new_pagination').html());
          			jQuery.observePagination(); 
					//Here we need to re-observe tab popup
					jQuery.observeTabDisplay(region);
        		}
      		});
    	});
	},

    observeMetadataForm: function(){
      jQuery('.datepicker').datepicker({
        changeMonth: true,
        changeYear: true,
        yearRange: 'c-300:c',
        dateFormat: 'yy-mm-dd'
      });
      jQuery('form .metadata ol').toggle();
      jQuery('form .metadata legend').bind({
        click: function(e){
          e.preventDefault();
          jQuery('form .metadata ol').toggle();
        },
        mouseover: function(){
          jQuery(this).css({cursor: 'hand'});
        },
        mouseout: function(){
          jQuery(this).css({cursor: 'pointer'});
        }
      });
    },

    observeMetadataDisplay: function(){
      jQuery('.metadatum-display').click(function(e){
          e.preventDefault();
          jQuery(this).find('ul').toggle();
      });
    },

    observeTagAutofill: function(className,controllerName){
      if(jQuery(className).length > 0){
       jQuery(className).live('click',function(){
         jQuery(this).tagSuggest({
           url: jQuery.rootPath() + controllerName + '/autocomplete_tags',
           separator: ', ',
           delay: 500
         });
       });
     }
    },

	/* Only used in collages.js */
    trim11: function(str) {
      // courtesty of http://blog.stevenlevithan.com/archives/faster-trim-javascript
    	var str = str.replace(/^\s+/, '');
    	for (var i = str.length - 1; i >= 0; i--) {
    		if (/\S/.test(str.charAt(i))) {
    			str = str.substring(0, i + 1);
    			break;
    		}
    	}
    	return str;
    },

	/* Only used in new_playlists.js */
    rootPathWithFQDN: function(){
      return location.protocol + '//' + location.hostname + ((location.port == 80 || location.port == 443) ? '' : ':' + location.port) + '/';
    },

    observeToolbar: function(){
      if(jQuery.cookie('tool-open') == '1'){
        jQuery('#tools').css({right: '0px', backgroundImage: 'none'});
      }

      jQuery('#tools').mouseenter(
        function(){
          jQuery.cookie('tool-open','1', {expires: 365});
          jQuery(this).animate({
            right: '0px'
            },250,'swing'
          );
          jQuery(this).css({backgroundImage: 'none'});
        }
      );

      jQuery('#hide').click(
        function(e){
          jQuery.cookie('tool-open','0', {expires: 365});
          e.preventDefault();
          jQuery('#tools').animate({
            right: '-280px'
          },250,'swing');
          jQuery('#tools').css({backgroundImage: "url('/images/elements/tools-vertical.gif')"});
      });
    },

    serializeHash: function(hashVals){
      var vals = [];
      for(var val in hashVals){
        if(val != undefined){
          vals.push(val);
        }
      }
      return vals.join(',');
    },
    unserializeHash: function(stringVal){
      if(stringVal && stringVal != undefined){
        var hashVals = [];
        var arrayVals = stringVal.split(',');
        for(var i in arrayVals){
          hashVals[arrayVals[i]]=1;
        }
        return hashVals;
      } else {
        return new Array();
      }
    },

    showGlobalSpinnerNode: function() {
		jQuery('#spinner').show();
	},
	hideGlobalSpinnerNode: function() {
		jQuery('#spinner').hide();
	},
	showMajorError: function(xhr) {
		//empty for now
	},
	getItemId: function(element) {
		if(jQuery("#results")) {
			return jQuery(element).closest(".listitem").data("itemid");		
		} else {
			return jQuery(".singleitem").data("itemid");
		}
	},

	/* 
	This is a generic UI function that applies to all elements with the "delete-action" class.
	With this, a dialog box is generated that asks the user if they want to delete the item (Yes, No).
	When a user clicks "Yes", an ajax call is made to the link's href, which responds with JSON.
	The listed item is then removed from the UI.
	*/
    observeDestroyControls: function(region){
	  	jQuery(region + ' .delete-action').live('click', function(e){
			var item_id = jQuery.getItemId(this);
        	var destroyUrl = jQuery(this).attr('href');
        	e.preventDefault();
        	var confirmNode = jQuery('<div><p>Are you sure you want to delete this item?</p></div>');
        	jQuery(confirmNode).dialog({
          		modal: true,
				close: function() {
					jQuery(confirmNode).remove();
				},
          		buttons: {
					Yes: function() {
              			jQuery.ajax({
                			cache: false,
                			type: 'POST',
                			url: destroyUrl,
                			dataType: 'JSON',
                			data: {'_method': 'delete'},
                			beforeSend: function(){
                  				jQuery.showGlobalSpinnerNode();
                			},
                			error: function(xhr){
                  				jQuery.hideGlobalSpinnerNode();
                  				//jQuery.showMajorError(xhr); 
                			},
                			success: function(data){
								if(data.type == 'playlist_item') {
									jQuery('.level0').each(function(i, el) {
										if(jQuery(el).data('itemid') == item_id) {
											jQuery(el).remove();
										}
									});
								} else {
									jQuery(".listitem" + item_id).animate({ opacity: 0.0, height: 0 }, 500, function() {
										jQuery(".listitem" + item_id).remove();
									});
								}
                  				jQuery.hideGlobalSpinnerNode();
                  				jQuery(confirmNode).remove();
							}
              			});
            		},
          			No: function(){
            			jQuery(confirmNode).remove();
          			}
				}
        	}).dialog('open');
		});
    },

	/*
	Generic bookmark item, more details here.
	*/
    observeBookmarkControls: function(region) {
	  	jQuery(region + ' .bookmark-action').live('click', function(e){
			var item_id = jQuery(".singleitem").data("itemid");
        	var actionUrl = jQuery(this).attr('href');
			var actionText = jQuery(this).html();
        	e.preventDefault();
			jQuery.ajax({
				cache: false,
				url: actionUrl,
				data: { "url" : location.href },
				beforeSend: function() {
                  	jQuery.showGlobalSpinnerNode();
				},
				success: function(html) {
                  	jQuery.hideGlobalSpinnerNode();
					jQuery.generateBookmarkNode(actionText, html);
				},
				error: function(xhr, textStatus, errorThrown) {
                  	jQuery.hideGlobalSpinnerNode();
				}
			});
		});
	},
	generateBookmarkNode: function(title, html) {
		if(jQuery.classType() == 'base') {
			html = html.replace(/<h2>.*<\/h2>/, '<h2>Bookmark this ' + jQuery('.bookmark-this').attr('href').replace(/\/bookmark_item\/item_/, '') + '</h2>');
		} else {
			html = html.replace(/<h2>.*<\/h2>/, '<h2>Bookmark this ' + jQuery.classType().replace(/s$/, '') + '</h2>');
		}
		var newItemNode = jQuery('<div id="bookmark-node"></div>').html(html);
		jQuery(newItemNode).dialog({
			title: title,
			modal: true,
			width: 'auto',
			height: 'auto',
			close: function() {
				jQuery(newItemNode).remove();
			},
			buttons: {
				Submit: function() {
					jQuery.submitBookmarkNode();
				},
				Close: function() {
					jQuery(newItemNode).remove();
				}
			}
		}).dialog('open');
	},
	submitBookmarkNode: function() {
		jQuery('#bookmark-node').find('form').ajaxSubmit({
			dataType: "JSON",
			beforeSend: function() {
				jQuery.showGlobalSpinnerNode();
			},
			success: function(data) {
				document.location.href = jQuery.rootPath() + 'playlists/' + data.id;
			},
			error: function(xhr) {
				jQuery.hideGlobalSpinnerNode();
				//message some error
			}
		});
	},


	/* Generic HTML form elements */
    observeGenericControls: function(region){
	  	jQuery(region + ' .remix-action,' + region + ' .edit-action,' + region + ' .new-action').live('click', function(e){
			var item_id = jQuery.getItemId(this);
        	var actionUrl = jQuery(this).attr('href');
			var actionText = jQuery(this).html();
        	e.preventDefault();
			jQuery.ajax({
				cache: false,
				url: actionUrl,
				beforeSend: function() {
                  	jQuery.showGlobalSpinnerNode();
				},
				success: function(html) {
                  	jQuery.hideGlobalSpinnerNode();
					jQuery.generateGenericNode(actionText, html);
				},
				error: function(xhr, textStatus, errorThrown) {
                  	jQuery.hideGlobalSpinnerNode();
				}
			});
		});
	},
	generateGenericNode: function(title, html) {
		var newItemNode = jQuery('<div id="generic-node"></div>').html(html);
		jQuery(newItemNode).dialog({
			title: title,
			modal: true,
			width: 'auto',
			height: 'auto',
			close: function() {
				jQuery(newItemNode).remove();
			},
			buttons: {
				Submit: function() {
					jQuery.submitGenericNode();
				},
				Close: function() {
					jQuery(newItemNode).remove();
				}
			}
		}).dialog('open');
	},
	submitGenericNode: function() {
		jQuery('#generic-node').find('form').ajaxSubmit({
			dataType: "JSON",
			beforeSend: function() {
				jQuery.showGlobalSpinnerNode();
			},
			success: function(data) {
				document.location.href = jQuery.rootPath() + jQuery.classType() + '/' + data.id;
			},
			error: function(xhr) {
				jQuery.hideGlobalSpinnerNode();
				//message some error
			}
		});
	}
});

jQuery(function() {
	
	/* Only used in collages */
    jQuery.fn.observeField =  function( time, callback ){
	    return this.each(function(){
	        var field = this, change = false;
	        jQuery(field).keyup(function(){
	            change = true;
	        });
	        setInterval(function(){
	            if ( change ) callback.call( field );
	            change = false;
	        }, time * 1000);
	    });
	}

  	//Fire functions for discussions
  	initDiscussionControls();


	/* TODO: Move a lot of this to custom jQuery functions */
	jQuery("#results .sort select").selectbox({
		className: "jsb"
	}).change(function() {
		//TODO: Modify this to use AJAX here, similar to pagination
		window.location = jQuery(this).val();
	});
	
	jQuery("#search .btn-tags").click(function() {
		var $p = jQuery(".browse-tags-popup");
		
		$p.toggle();
		jQuery(this).toggleClass("active");
		
		return false;
	});
	
	jQuery("#playlist .playlist .data .dd-open").click(function() {
		jQuery(this).parents(".playlist:eq(0)").find(".playlists:eq(0)").slideToggle();
		
		return false;
	});
	
	jQuery("#collage .description .buttons ul .btn-a span").parent().click(function() { 
		jQuery('.tools-popup').css({ 'top': 25 }).toggle();
		jQuery(this).toggleClass("btn-a-active");
		return false;
	});

	jQuery(".search_all input[type=radio]").click(function() {
		jQuery(".search_all form").attr("action", "/" + jQuery(this).val());
	});
	jQuery("#search_all_radio").click();

	jQuery(".tabs a").click(function() {
		jQuery(".popup").fadeOut().removeData('item_id');
		jQuery(".tabs a").removeClass("active");
		jQuery('.songs > ul').hide();
		jQuery("#" + jQuery(this).data('region')).show();
		jQuery(this).addClass("active");
	});

	jQuery(".link-more,.link-less").click(function() {
		jQuery("#description_less,#description_more").toggle();
	});

    jQuery('.item_drag_handle').button({icons: {primary: 'ui-icon-arrowthick-2-n-s'}});

	jQuery('.link-copy').click(function() {
		jQuery(this).closest('form').submit();
	});
	//jQuery('#results .song details .influence input').rating();
	//jQuery('#playlist details .influence input').rating();

	/* End TODO */

	jQuery.observeDestroyControls('');
	jQuery.observeGenericControls('');
	jQuery.observeBookmarkControls('');
	jQuery.observePagination(); 
	jQuery.observeTabDisplay('');
});
