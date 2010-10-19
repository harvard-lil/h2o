jQuery.extend({
    submitPlaylist: function(className){
        jQuery('#playlist-editor').find('form').ajaxSubmit({
            dataType: 'script',
            beforeSend: function(){
                jQuery('#spinner_block').show();
                jQuery('#error_block').hide();
            },
            success: function(response){
                jQuery('#spinner_block').hide();
                jQuery('#playlist-editor').dialog('close');
                document.location.href = jQuery.rootPath() + 'playlists/'
            },
            error: function(xhr){
                jQuery('#spinner_block').show();
                jQuery('#error_block').show().html(xhr.responseText);
            }
        });
    },

    initPlaylistEditControls: function(className){
        jQuery(className).click(function(e){
            e.preventDefault();
            jQuery.ajax({
                cache: false,
                dataType: 'script',
                url: jQuery(this).attr('href'),
                beforeSend: function(){
                    jQuery('#spinner_block').show();
                },
                success: function(html){
                    jQuery('#spinner_block').hide();
                    var newPlaylistNode = jQuery('<div id="playlist-editor"></div>');
                    jQuery(newPlaylistNode).dialog({
                        title: 'Edit Playlist',
                        modal: true,
                        width: 500,
                        height: 400,
                        position: 'top',
                        close: function(){
                            jQuery(newPlaylistNode).remove();
                        },
                        buttons: {
                            Save: function(){
                                jQuery.submitPlaylist(className);
                            },
                            Close: function(){
                                jQuery(newPlaylistNode).dialog('close');
                            }
                        }
                    });
                    jQuery(newPlaylistNode).html(html);
                    jQuery(newPlaylistNode).dialog('open');
                },
                error: function(xhr){
                    jQuery('#spinner_block').hide();

                }
            });
        });
    },
    initPlaylistDeleteControls: function(){
        jQuery('.delete-playlist').click(function(e){
            var url = jQuery(this).attr('href');
            e.preventDefault();
            var confirmNode = jQuery('<div>Are you sure you want to delete this playlist?</div>');
            jQuery(confirmNode).dialog({
                title: 'Are you sure you want to delete this playlist?',
                modal: true,
                position: 'top',
                width: 500,
                close: function(){
                    jQuery(confirmNode).remove();
                },
                buttons: {
                    Yes: function(){
                        jQuery.ajax({
                            type: 'POST',
                            dataType: 'script',
                            url: url,
                            data: {
                                '_method': 'DELETE'
                            },
                            beforeSend: function(){
                                jQuery('#spinner_block').show();
                            },
                            success: function(html){
                                jQuery('#spinner_block').hide();
                                document.location.href = jQuery.rootPath() + 'playlists/';
                            },
                            error: function(xhr){
                                jQuery('#spinner_block').hide();
                                jQuery(confirmNode).html(xhr.responseText);
                            }
                        });
                    },
                    No: function(){
                        jQuery(confirmNode).dialog('close');
                        jQuery(confirmNode).remove();
                    }
                }
            });
        });
    },
    initPlaylistItemAddControls: function(){
        jQuery('.new-playlist-item').click(function(e){
            e.preventDefault();
            jQuery.ajax({
                type: 'GET',
                dataType: 'script',
                url: jQuery(this).attr('href'),
                beforeSend: function(){
                    jQuery('#spinner_block').show()
                },
                success:function(html){
                    jQuery('#spinner_block').hide();
                    var itemChooserNode = jQuery('<div id="dialog-item-chooser"></div>');
                    jQuery(itemChooserNode).html(html);
                    jQuery(itemChooserNode).dialog({
                      title: "Add an item to this playlist",
                      modal: true,
                      width: 500,
                      height: 400,
                      position: 'top',
                      close: function(){
                        jQuery(itemChooserNode).remove();
                      }
                    });
                    jQuery("#url_review").button();
                    jQuery('#tabs').tabs();
                    jQuery.observeItemObjectLists();
                },
                error: function(xhr){
                    jQuery('#spinner_block').hide();
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
                dataType: 'script',
                url: jQuery.rootPath() + 'item_' + itemController + '/new',
                beforeSend: function(){
                    jQuery('#spinner_block').show();
                },
                data: {
                    url_string: jQuery.rootPathWithFQDN() + itemController + '/' + itemId,
                    container_id: jQuery('#container_id').text()
                },
                success: function(html){
                    jQuery('#spinner_block').hide();
                    jQuery('#dialog-item-chooser').dialog('close');
                    var addItemDialog = jQuery('<div id="add-item-dialog"></div>');
                    jQuery(addItemDialog).html(html);
                    jQuery(addItemDialog).dialog({
                      title: 'Add ' + itemName ,
                      modal: true,
                      width: 500,
                      height: 400,
                      position: 'top',
                      close: function(){
                        jQuery(addItemDialog).remove();
                      },
                      buttons: {
                        Save: function(){
                         //TODO: handle ajax submission here.
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
                    jQuery('#spinner_block').show();
                },
                data: {
                    keywords: jQuery('#' + itemName + '-keyword-search').val()
                    },
                dataType: 'script',
                success: function(html){
                    jQuery('#spinner_block').hide();
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
                      jQuery('#spinner_block').show();
                    },
                    data: {
                        keywords: jQuery('#' + itemName + '-keyword-search').val()
                        },
                    url: jQuery(this).attr('href'),
                    success: function(html){
                        jQuery('#spinner_block').hide();
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
            dataType: 'script',
            beforeSend: function(){
              jQuery('#spinner_block').show();
            },
            success: function(html){
              jQuery('#spinner_block').hide();
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
    jQuery('.button').button();
    jQuery.initPlaylistEditControls('.new-playlist,.edit-playlist');
    jQuery.initPlaylistDeleteControls();
    jQuery.initPlaylistItemAddControls();
});
