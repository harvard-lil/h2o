var dragged_element;
var is_owner = false;

jQuery.extend({
  initializeNoteFunctionality: function() {
    jQuery('.public-notes,.private-notes').click(function(e) {
      jQuery.showGlobalSpinnerNode();
      var type = jQuery(this).data('type');
      e.preventDefault();
      jQuery.ajax({
        type: 'post',
        dataType: 'json',
        url: '/playlists/' + jQuery('#playlist').data('itemid') + '/notes/' + type,
        success: function(results) {
          jQuery.hideGlobalSpinnerNode();
          if(type == 'public') {
            jQuery('.notes b').html('Additional Notes:');
          } else {
            jQuery('.notes b').html('Additional Notes (private):');
          }
        }
      });
    });
  },
  observeStats: function() {
		jQuery('#playlist-stats').click(function() {
			jQuery(this).toggleClass("active");
      if(jQuery('#playlist-stats-popup').height() < 400) {
        jQuery('#playlist-stats-popup').css('overflow', 'hidden');
      } else {
        jQuery('#playlist-stats-popup').css('height', 400);
      }
			jQuery('#playlist-stats-popup').slideToggle('fast');
			return false;
		});
  },
  observeFontChange: function() {
    var val = jQuery.cookie('font_size');
    if(val != null) {
      jQuery('.font-size-popup select').val(val);
      jQuery('.icon-type').css('margin-top', (parseFloat(val) - 8)/2 + 'px');
      jQuery('#playlist .details h5').css('font-size', val + 'px');
      jQuery('#playlist .details #description').css('font-size', (parseInt(val) + 2) + 'px');
      jQuery('#playlist .details p').css('font-size', (parseInt(val) + 2) + 'px');
      jQuery('#playlist .details #description_less').css('font-size', (parseInt(val) + 2) + 'px');
      jQuery('.playlist .data p').css('font-size', val + 'px');
      jQuery('.playlist .data div').css('font-size', val + 'px');
      jQuery('.playlist .data h3').css('font-size', (parseInt(val) + 4) + 'px');
    }
    jQuery("#playlist .description .buttons ul #fonts span").parent().click(function() { 
      jQuery('.font-size-popup').css({ 'top': 25 }).toggle();
      jQuery(this).toggleClass("btn-a-active");
      if(jQuery(this).hasClass("btn-a-active")) {
        jQuery('.font-size-popup .jsb-moreButton').click();
      }
      return false;
    });
    jQuery('.font-size-popup select').selectbox({
      className: "jsb", replaceInvisible: true 
    }).change(function() {
      var element = jQuery(this);
      jQuery.cookie('font_size', element.val(), { path: "/" });
      jQuery('.icon-type').css('margin-top', (parseFloat(element.val()) - 8)/2 + 'px');
      jQuery('#playlist .details h5').css('font-size', element.val() + 'px');
      jQuery('#playlist .details #description').css('font-size', (parseInt(element.val()) + 2) + 'px');
      jQuery('#playlist .details p').css('font-size', (parseInt(element.val()) + 2) + 'px');
      jQuery('#playlist .details #description_less').css('font-size', (parseInt(element.val()) + 2) + 'px');
      jQuery('.playlist .data p').css('font-size', element.val() + 'px');
      jQuery('.playlist .data div').css('font-size', element.val() + 'px');
      jQuery('.playlist .data h3').css('font-size', (parseInt(element.val()) + 4) + 'px');
    });
  },
	observeDragAndDrop: function() {
    if(is_owner) {
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
    }
	},
  initPlaylistItemAddControls: function(){
        jQuery('.new-playlist-item-control').click(function(e){
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
                    jQuery('#tabs').tabs();
                    jQuery.observeItemObjectLists();
					jQuery.initAddUrlButton();
                },
                error: function(xhr, textStatus, errorThrown) {
               		jQuery.hideGlobalSpinnerNode();
                }
            });

        });
    },

    initAddUrlButton: function(itemName, itemController){
        jQuery('#url_review').click(function(e){
            e.preventDefault();
            if(jQuery(this).hasClass('inactive')) {
              return false;
            }
            jQuery(this).addClass('inactive');
            /* var itemId = jQuery(this).attr('id').split('-')[1]; */
            jQuery.addItemToPlaylistDialog('defaults', 'URL', jQuery('#url_input').val(), container_id);
        });
    },
    initPlaylistItemAddButton: function(itemName, itemController){
        jQuery('.add-' + itemName + '-button').button().click(function(e){
            e.preventDefault();
            if(jQuery(this).hasClass('inactive')) {
              return false;
            }
            jQuery(this).addClass('inactive');
            var itemId = jQuery(this).attr('id').split('-')[1];
            jQuery.addItemToPlaylistDialog(itemController, itemName, itemId, container_id);
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
                dataType: 'html',
                success: function(html){
               		jQuery.hideGlobalSpinnerNode();
                    jQuery('.h2o-playlistable-' + itemName).html(html);
                    jQuery.initPlaylistItemAddButton(itemName, itemController);
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
                    dataType: 'html',
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
                        jQuery.initPlaylistItemAddButton(itemName, itemController);
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
                        jQuery.initPlaylistItemAddButton(itemName, itemController);
                        jQuery.initKeywordSearch(itemName,itemController);
                        jQuery.initPlaylistItemPagination(itemName,itemController);
                    }
                });
            }
        });
    }
});

jQuery(document).ready(function(){
  var height = jQuery('.description').height();
  if(height != 30) {
    jQuery('.toolbar,.buttons').css({ position: 'relative', top: height - 30 });
  }
  jQuery('.toolbar, .buttons').css('visibility', 'visible');
  jQuery.loadEditability();
  jQuery.observeStats();
  jQuery.observeFontChange();
  jQuery.initPlaylistItemAddControls();
  jQuery.initializeNoteFunctionality();
});
