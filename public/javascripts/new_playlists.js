var dragged_element;

jQuery.extend({
	observeDragAndDrop: function() {
		jQuery('.sortable').sortable({
			stop: function(event, ui) {
				var playlist_order = jQuery('.sortable').sortable('serialize');
				jQuery.ajax({
					type: 'post',
					dataType: 'json',
					url: '/playlists/' + jQuery('#playlist').data('itemid') + '/position_update',
					data: {
						playlist_order: playlist_order
					},
                	beforeSend: function(){
               			jQuery.showGlobalSpinnerNode();
                	},
					success: function(data) {
						jQuery.each(data, function(index, value) {
							var current_val = jQuery('#playlist_item_' + index + ' .number:first').html();
							if(current_val != value) {
								var posn_rep = new RegExp('^' + current_val + '');
								jQuery('#playlist_item_' + index + ' .number').each(function(i, el) {
									jQuery(el).html(jQuery(el).html().replace(posn_rep, value));
								});
							}
						});
					},
					complete: function() {
               			jQuery.hideGlobalSpinnerNode();
					}
				});
			}
		}); 
	},
    initPlaylistItemAddControls: function(){
        jQuery('.new-playlist-item').click(function(e){
            e.preventDefault();
            jQuery.ajax({
                type: 'GET',
				dataType: "html",
                url: jQuery(this).attr('href'),
                beforeSend: function(){
               		jQuery.showGlobalSpinnerNode();
                },
                success:function(html){
               		jQuery.hideGlobalSpinnerNode();
                    var itemChooserNode = jQuery('<div id="dialog-item-chooser"></div>');
                    jQuery(itemChooserNode).html(html);
                    jQuery(itemChooserNode).dialog({
                        title: "Add an item to this playlist",
                        modal: true,
                        width: 'auto',
                        height: 'auto',
                        position: 'top',
                        close: function(){
                            jQuery(itemChooserNode).remove();
                        }
                    });
                    jQuery("#url_review").button();
                    jQuery('#tabs').tabs();
                    jQuery.observeItemObjectLists();
                },
                error: function(xhr, textStatus, errorThrown) {
               		jQuery.hideGlobalSpinnerNode();
                }
            });

        });
    },

    initPlaylistItemAddButton: function(itemName, itemController){
        jQuery('.add-' + itemName + '-button').button().click(function(e){
            e.preventDefault();
            var itemId = jQuery(this).attr('id').split('-')[1];
            jQuery.ajax({
                method: 'GET',
                cache: false,
                dataType: "html",
                url: jQuery.rootPath() + 'item_' + itemController + '/new',
                beforeSend: function(){
               		jQuery.showGlobalSpinnerNode();
                },
                data: {
                    url_string: jQuery.rootPathWithFQDN() + itemController + '/' + itemId,
                    container_id: jQuery('#container_id').text()
                },
                success: function(html){
               		jQuery.hideGlobalSpinnerNode();
                    jQuery('#dialog-item-chooser').dialog('close');
                    var addItemDialog = jQuery('<div id="generic-node"></div>');
                    jQuery(addItemDialog).html(html);
                    jQuery(addItemDialog).dialog({
                        title: 'Add ' + itemName ,
                        modal: true,
                        width: 'auto',
                        height: 'auto',
                        position: 'top',
                        close: function(){
                            jQuery(addItemDialog).remove();
                        },
                        buttons: {
                            Save: function(){
								jQuery.submitGenericNode();
                            },
                            Close: function(){
                                jQuery(addItemDialog).dialog('close');
                            }
                        }
                    });
                }
            });
        });
    },
    initKeywordSearch: function(itemName,itemController){
        jQuery('.' + itemName + '-button').button().click(function(e){
            e.preventDefault();
            jQuery.ajax({
                method: 'GET',
                url: jQuery.rootPath() + itemController + '/embedded_pager',
                beforeSend: function(){
               		jQuery.showGlobalSpinnerNode();
                },
                data: {
                    keywords: jQuery('#' + itemName + '-keyword-search').val()
                },
                dataType: 'script',
                success: function(html){
               		jQuery.hideGlobalSpinnerNode();
                    jQuery('.h2o-playlistable-' + itemName).html(html);
                    jQuery.initPlaylistItemAddButton(itemName,itemController);
                    jQuery.initKeywordSearch(itemName,itemController);
                    jQuery.initPlaylistItemPagination(itemName,itemController);
                }
            });
        });
    },
    initPlaylistItemPagination: function(itemName,itemController){
        jQuery('.h2o-playlistable-' + itemName + ' .pagination a').click(
            function(e){
                e.preventDefault();
                jQuery.ajax({
                    type: 'GET',
                    dataType: 'script',
                    beforeSend: function(){
               			jQuery.showGlobalSpinnerNode();
                    },
                    data: {
                        keywords: jQuery('#' + itemName + '-keyword-search').val()
                    },
                    url: jQuery(this).attr('href'),
                    success: function(html){
               			jQuery.hideGlobalSpinnerNode();
                        jQuery('.h2o-playlistable-' + itemName).html(html);
                        jQuery.initPlaylistItemAddButton(itemName,itemController);
                        jQuery.initKeywordSearch(itemName,itemController);
                        jQuery.initPlaylistItemPagination(itemName,itemController);
                    }
                });
            });
    },
    observeItemObjectLists: function(){
        jQuery('[class^=playlistable-object-list]').each(function(){
            var playlistParams = jQuery(this).attr('class').split(/\-/);
            var itemName = playlistParams[3];
            var itemController = playlistParams[4];
            if(jQuery(this).html().length < 15){
                jQuery.ajax({
                    method: 'GET',
                    cache: false,
                    url: jQuery.rootPath() + itemController + '/embedded_pager',
                    dataType: "html",
                    beforeSend: function(){
               			jQuery.showGlobalSpinnerNode();
                    },
                    success: function(html){
               			jQuery.hideGlobalSpinnerNode();
                        jQuery('.h2o-playlistable-' + itemName).html(html);
                        jQuery.initPlaylistItemAddButton(itemName,itemController);
                        jQuery.initKeywordSearch(itemName,itemController);
                        jQuery.initPlaylistItemPagination(itemName,itemController);
                    }
                });
            }
        });
    }
});

jQuery(document).ready(function(){
    jQuery.initPlaylistItemAddControls();
	if(owner_can_sort) {
		jQuery.observeDragAndDrop();
	}
});
