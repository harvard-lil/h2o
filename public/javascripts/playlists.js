var dragged_element;
var dropped_item;
var remove_item;
var dropped_original_position;
var items_dd_handles;

jQuery.extend({
  playlist_afterload: function(results) {
    if(results.can_edit || results.can_edit_notes || results.can_edit_desc) {
      if (results.can_edit) {
        jQuery('.requires_edit, .requires_remove').animate({ opacity: 1.0 });
        jQuery('#edit_toggle').click();
        is_owner = true;
      } else {
        if(!results.can_edit_notes) {
          jQuery('#description .public-notes, #description .private-notes').remove();
        }
        if(!results.can_edit_desc) {
          jQuery('#description .icon-edit').remove();
        }
        jQuery('.requires_remove').remove();
        jQuery('.requires_edit').animate({ opacity: 1.0 });
      }
    } else {
      jQuery('.requires_edit, .requires_remove').remove();
    }
    var notes = jQuery.parseJSON(results.notes) || new Array() 
    jQuery.each(notes, function(i, el) {
      if(el.playlist_item.notes != null) {
        var title = el.playlist_item.public_notes ? "Additional Notes" : "Additional Notes (private)";
        var node = jQuery('<div>').html('<b>' + title + ':</b><br />' + el.playlist_item.notes).addClass('notes');
        if(jQuery('#playlist_item_' + el.playlist_item.id + ' > .data .notes').length) {
          jQuery('#playlist_item_' + el.playlist_item.id + ' > .data .notes').remove();
        } 
        jQuery('#playlist_item_' + el.playlist_item.id + ' > .data').append(node);
      }
    });
    jQuery('.add-popup select option').remove();
  },
  observeViewerToggleEdit: function() {
    jQuery('#edit_toggle').click(function(e) {
      e.preventDefault();
      jQuery('#edit_item #status_message').remove();
      var el = jQuery(this);
      if(jQuery(this).hasClass('edit_mode')) {
        el.removeClass('edit_mode');
        jQuery('body').removeClass('playlist_edit_mode');
        jQuery('#playlist .dd').removeClass('playlists-edit-mode');
        jQuery('#playlist .dd .icon').removeClass('hover');
        if(jQuery('#collapse_toggle').hasClass('expanded')) {
          jQuery('#edit_item').hide();
          jQuery('.singleitem').addClass('expanded_singleitem');
        } else {
          jQuery('#edit_item').hide();
          jQuery('#stats').show();
          jQuery.resetRightPanelThreshold();
          jQuery.checkForPanelAdjust();
        }
        jQuery.unObserveDragAndDrop();
      } else {
        el.addClass('edit_mode');
        jQuery('body').addClass('playlist_edit_mode');
        jQuery('#playlist .dd').addClass('playlists-edit-mode');
        jQuery('#playlist .dd .icon').addClass('hover');
        if(jQuery('#collapse_toggle').hasClass('expanded')) {
          jQuery('#collapse_toggle').removeClass('expanded');
          jQuery('.singleitem').removeClass('expanded_singleitem');
          jQuery('#edit_item').show();
          jQuery.resetRightPanelThreshold();
        } else {
          jQuery('#stats').hide();
          jQuery('#edit_item').show();
          jQuery.resetRightPanelThreshold();
        }
        jQuery.observeDragAndDrop();
        jQuery.checkForPanelAdjust();
      }
    });
  },
  observeAdditionalDetailsExpansion: function() {
    jQuery('.listitem .wrapper').hoverIntent(function() {
      jQuery(this).find('a.title,a.author_link,a.rr').addClass('hover_link');
      if(!jQuery(this).parent().hasClass('adding-item')) {
        if(jQuery('.adding-item').size()) {
          jQuery('.add-popup').hide();
          jQuery('.adding-item').removeClass('adding-item');
        }
        if(!jQuery('div.dd').hasClass('playlists-edit-mode') && !jQuery(this).parent().hasClass('expanded')) {
          jQuery(this).find('.icon').addClass('hover');
        }
      }
    }, function() {
      jQuery(this).find('a.title,a.author_link,a.rr').removeClass('hover_link');
      if(!jQuery('div.dd').hasClass('playlists-edit-mode') && !jQuery(this).parent().hasClass('expanded') && !jQuery(this).parent().hasClass('adding-item')) {
        jQuery(this).find('.icon').removeClass('hover');
      }
    });
  },
  observePlaylistExpansion: function() {
    jQuery(".playlist .rr").live('click', function() {
      jQuery(this).toggleClass('rr-closed');
      var playlist = jQuery(this).parents(".playlist:eq(0)");
      playlist.find('> .wrapper > .inner-wrapper > .additional_details').slideToggle();
      playlist.find('.playlists:eq(0)').slideToggle();
      playlist.toggleClass('expanded');
      return false;
    });
  },
  update_positions: function(position_data) {
    jQuery.each(position_data, function(index, value) {
      var current_val = jQuery('#playlist_item_' + index + ' .number:first').html();
      if(current_val != value) {
        var posn_rep = new RegExp('^' + current_val + '');
        jQuery('#playlist_item_' + index + ' .number').each(function(i, el) {
          jQuery(el).html(jQuery(el).html().replace(posn_rep, value));
        });
      }
    });
    if(jQuery('#playlist .dd-item').size() == 0) {
      jQuery('#playlist .dd-list').addClass('dd-empty');
    }
  },
  observeDeleteNodes: function() {
    jQuery('#playlist .delete-playlist-item').live('click', function(e) {
      jQuery.cancelItemAdd();
      e.preventDefault();
      var listing = jQuery(this).parentsUntil('.listitem').last();
      listing.parent().addClass('listing-with-delete-form');
      var data = { "url" : jQuery(this).attr('href') }; 
      var content = jQuery(jQuery.mustache(delete_playlist_item_template, data)).css('display', 'none');
      content.appendTo(listing);
      content.slideDown(200);
    });
  },
  observeEditNodes: function() {
    jQuery('#playlist .edit-playlist-item').live('click', function(e) {
      jQuery.cancelItemAdd();
      e.preventDefault();
      var url = jQuery(this).attr('href');
      var listing = jQuery(this).parentsUntil('.listitem').last();
      listing.parent().addClass('listing-with-edit-form');
      jQuery.ajax({
        cache: false,
        url: url,
        beforeSend: function() {
            jQuery.showGlobalSpinnerNode();
        },
        success: function(html) {
          jQuery.hideGlobalSpinnerNode();
          var content = jQuery(html).css('display', 'none');
          content.appendTo(listing);
          content.slideDown(200);
        },
        error: function(xhr, textStatus, errorThrown) {
          jQuery.hideGlobalSpinnerNode();
        }
      });
    });
  },
  renderEditPlaylistItem: function(item) {
	  jQuery('#playlist_item_form').slideUp(200, function() {
      jQuery(this).remove();
    });
    var listitem_wrapper = jQuery('.listitem' + item.id + ' > .wrapper');
    listitem_wrapper.find('a.title').html(item.name);

    //Description changes
    var resource_item_desc = listitem_wrapper.find('.resource_item_desc');
    if(resource_item_desc.size() == 0 && item.description != '') {
      var new_item = jQuery('<div>').attr('class', 'resource_item_desc').html(item.description);
      if(listitem_wrapper.find('.additional_details').size() == 0) {
        listitem_wrapper.find('.rr-cell').append(jQuery('<a href="#" class="rr rr-closed" id="rr' + item.id + '">Show/Hide More</a>'));
        var add_details = jQuery('<div>').addClass('additional_details');
        add_details.append(new_item);
        add_details.insertAfter(listitem_wrapper.find('table'));
      } else {
        if(listitem_wrapper.find('.creator_details').size()) {
          new_item.insertAfter(listitem_wrapper.find('.creator_details'));
        } else {
          listitem_wrapper.find('.additional_details').prepend(new_item);
        }
      }
    } else if(resource_item_desc.size() && item.description == '') {
      resource_item_desc.remove();
    } else if(resource_item_desc.size() && item.description != '') {
      resource_item_desc.html(item.description);
    }

    //Notes changes
    var notes_item = listitem_wrapper.find('.notes');
    if(notes_item.size() == 0 && item.notes != '') {
      var new_item = jQuery('<div>').attr('class', 'notes').html(item.notes);
      if(listitem_wrapper.find('.additional_details').size() == 0) {
        listitem_wrapper.find('.rr-cell').append(jQuery('<a href="#" class="rr rr-closed" id="rr' + item.id + '">Show/Hide More</a>'));
        var add_details = jQuery('<div>').addClass('additional_details');
        add_details.append(new_item);
        add_details.insertAfter(listitem_wrapper.find('table'));
      } else {
        if(listitem_wrapper.find('.actual_obj_desc').size()) {
          new_item.insertBefore(listitem_wrapper.find('.actual_obj_desc'));
        } else {
          listitem_wrapper.find('.additional_details').append(new_item);
        }
      }
    } else if(notes_item.size() && item.notes == '') {
      notes_item.remove();
    } else if(notes_item.size() && item.notes != '') {
      notes_item.html(item.notes);
    }

    if(listitem_wrapper.find('.additional_details *').size() == 0) {
      listitem_wrapper.find('.rr').remove();
      listitem_wrapper.find('.additional_details').remove();
    }
  },
  renderNewPlaylistItem: function(data) {
    jQuery.ajax({
      type: 'get',
      url: '/playlist_items/' + data.playlist_item_id,
      success: function(response) {
        jQuery('.playlists .dd-list .listing').replaceWith(response);
        jQuery('.requires_edit,.requires_remove,.requires_logged_in').animate({ opacity: 1.0 });
        jQuery.update_positions(data.position_data);
      }, 
      error: function() {
        setTimeout(function() {
          document.location.href = jQuery.rootPath() + data.type + '/' + data.id;
        }, 1000); 
      }
    });
  },
  observeNoteFunctionality: function() {
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
  cancelItemAdd: function() {
    if(dropped_item) {
	    remove_item = dropped_item;
	    dropped_item = undefined;
	    remove_item.data('drop', 'canceled');
	    remove_item.slideUp(200, function() {
	      remove_item.detach();
	      remove_item.find('#playlist_item_form').remove();
	      jQuery('#nestable2 .dd-list li:nth-child(' + dropped_original_position + ')').before(remove_item);
	      remove_item.slideDown(200, function() {
	        remove_item.data('drop', 'new_item');
	      });
	    });
    }
    if(jQuery('.listitem #playlist_item_form')) {
	    jQuery('#playlist_item_form').slideUp(200, function() {
        jQuery(this).remove();
      });
    }
  },
  observePlaylistManipulation: function() {
    jQuery('#playlist_item_delete').live('click', function(e) {
      e.preventDefault();
      var destroy_url = jQuery(this).attr('href');
      jQuery.ajax({
        cache: false,
        type: 'POST',
        url: destroy_url,
        dataType: 'JSON',
        data: { '_method' : 'delete' },
        beforeSend: function() {
          jQuery.showGlobalSpinnerNode();
        },
        error: function(xhr) {
          jQuery.hideGlobalSpinnerNode();
        },
        success: function(data) {
	        jQuery('.listing-with-delete-form').slideUp(200, function() {
            jQuery(this).remove();
          });
          jQuery.update_positions(data.position_data);
          jQuery.hideGlobalSpinnerNode();
        }
      });
    });
    jQuery('#playlist_item_submit').live('click', function(e) {
      e.preventDefault();
      var form = jQuery(this).closest('form');
      var new_item = form.hasClass('new');
      form.ajaxSubmit({
        dataType: "JSON",
        beforeSend: function() {
          jQuery.showGlobalSpinnerNode();
        },
        success: function(data) {
          if(data.error) {
            jQuery('#error_block').html(data.message).show();
          } else {
            if(form.hasClass('new')) {
              jQuery.renderNewPlaylistItem(data);
            } else {
              jQuery.renderEditPlaylistItem(data);
            }
          }
          jQuery.hideGlobalSpinnerNode();
        },
        error: function(xhr) {
          jQuery.hideGlobalSpinnerNode();
        }
      });
    });
    jQuery('#playlist_item_cancel').live('click', function(e) {
      e.preventDefault();
      jQuery.cancelItemAdd();
    });
  },
  unObserveDragAndDrop: function() {
    if(access_results.can_position_update) {
      jQuery('.dd-handle').removeClass('dd-handle').addClass('dd-handle-inactive');
    }
  },
  observeDragAndDrop: function() {
    if(access_results.can_position_update) {
      jQuery('.dd-handle-inactive').removeClass('dd-handle-inactive').addClass('dd-handle');
      jQuery('div.playlists').nestable({ group: 1 });
      jQuery('div.playlists').on('custom_change', function() {
        if(dropped_item !== undefined) {
          jQuery.cancelItemAdd();
        }

        var position_update = true; 
        var new_item;
        var order = jQuery('div.playlists').nestable('serialize');
        var positions = new Array();
        jQuery.each(order, function(i, item) {
          if(item.drop == "new_item") {
            position_update = false;
            new_item = item;
          } else {
            positions.push("playlist_item[]=" + item.id);
          }
        });
        if(position_update) {
          jQuery.ajax({
            type: 'post',
            dataType: 'json',
            url: '/playlists/' + jQuery('#playlist').data('itemid') + '/position_update',
            data: {
              playlist_order: positions.join('&')
            },
            beforeSend: function(){
              jQuery.showGlobalSpinnerNode();
            },
            success: function(data) {
              jQuery.update_positions(data);
            },
            complete: function() {
              jQuery.hideGlobalSpinnerNode();
            }
          });
        } else {
			    var url_string = jQuery.rootPathWithFQDN() + new_item.type + '/' + new_item.id;
          var listing_el = jQuery('#listing_' + new_item.type + '_' + new_item.id);

          dropped_item = listing_el;
          dropped_original_position = new_item.index + 1; 
			    jQuery.ajax({
			      method: 'GET',
			      cache: false,
			      dataType: "html",
			      url: jQuery.rootPath() + 'item_' + new_item.type + '/new',
			      beforeSend: function(){
			           jQuery.showGlobalSpinnerNode();
			      },
			      data: {
			        url_string: url_string,
			        container_id: container_id,
              position: jQuery('.playlists ol.dd-list .dd-item').index(listing_el) + 1
			      },
			      success: function(html){
			        jQuery.hideGlobalSpinnerNode();
              var new_content = jQuery(html);
              listing_el.find('.icon').addClass('hover');
              listing_el.append(new_content).css({ height: 'auto', 'border-top': 'none' }).addClass('listing-with-form');
              listing_el.find('.dd-handle').show();
			      }
			    });
        }
      });
    }
  },
  initHeaderPagination: function() {
    jQuery('#add_item_results #header a#right_page:not(.inactive)').live('click', function(e) {
      jQuery('.pagination a.next_page').click();
    });
    jQuery('#add_item_results #header a#left_page:not(.inactive)').live('click', function(e) {
      jQuery('.pagination a.prev_page').click();
    });
    return;
  },
  toggleHeaderPagination: function() {
    if(jQuery('.pagination a.next_page').size()) {
      jQuery('#add_item_results #header a#right_page').removeClass('inactive');
    } else {
      jQuery('#add_item_results #header a#right_page').addClass('inactive');
    }
    if(jQuery('.pagination a.prev_page').size()) {
      jQuery('#add_item_results #header a#left_page').removeClass('inactive');
    } else {
      jQuery('#add_item_results #header a#left_page').addClass('inactive');
    }
    return;
  },
  initKeywordSearch: function() {
    jQuery('#add_item_search').live('click', function(e) {
      e.preventDefault();
      var itemController = jQuery('#add_item_select').val();
      jQuery.ajax({
        method: 'GET',
        url: jQuery.rootPath() + itemController + '/embedded_pager',
        beforeSend: function(){
           jQuery.showGlobalSpinnerNode();
        },
        data: {
          keywords: jQuery('#add_item_term').val(),
          sort: jQuery('#add_item_results .sort select').val() 
        },
        dataType: 'html',
        success: function(html){
          jQuery.hideGlobalSpinnerNode();
          jQuery('#add_item_results').html(html);
          jQuery.toggleHeaderPagination();
          jQuery('div#nestable2').nestable({ group: 1, maxDepth: 1 });
          jQuery.initializeBarcodes();
          jQuery('#add_item_results .sort select').selectbox({
            className: "jsb", replaceInvisible: true 
          }).change(function() {
            jQuery('#add_item_search').click(); 
          });
        }
      });
    });
  },
  initPlaylistItemPagination: function() {
    jQuery('.pagination a').live('click', function(e) {
      e.preventDefault();
      jQuery.ajax({
        type: 'GET',
        dataType: 'html',
        beforeSend: function(){
         jQuery.showGlobalSpinnerNode();
        },
        data: {
          keywords: jQuery('#add_item_term').val()
        },
        url: jQuery(this).attr('href'),
        success: function(html){
          jQuery.hideGlobalSpinnerNode();
          jQuery('#add_item_results').html(html);
          jQuery.toggleHeaderPagination();
          jQuery('div#nestable2').nestable({ group: 1, maxDepth: 1 });
          jQuery('#add_item_results .sort select').selectbox({
            className: "jsb", replaceInvisible: true 
          }).change(function() {
            jQuery('#add_item_search').click(); 
          });
        }
      });
    });
  }
});

jQuery(document).ready(function(){
  jQuery.setPlaylistFontHierarchy(14);

  jQuery('.toolbar, .buttons').css('visibility', 'visible');
  jQuery.observeStats();
  jQuery.observeNoteFunctionality();

  /* New Item Search */
  jQuery('#add_item_select').selectbox({
    className: "jsb", replaceInvisible: true 
  });
  jQuery.initKeywordSearch();
  jQuery.initHeaderPagination();
  jQuery.initPlaylistItemPagination();
  /* End New Search */
  
  jQuery.observeEditNodes();
  jQuery.observeDeleteNodes();
  jQuery.observePlaylistManipulation();
  jQuery.observePlaylistExpansion();
  jQuery.observeAdditionalDetailsExpansion();
  jQuery.observeViewerToggleEdit();
});

var delete_playlist_item_template = '\
<div id="playlist_item_form" class="delete">\
<p>Are you sure you want to delete this playlist item?</p>\
<a href="{{url}}" id="playlist_item_delete">YES</a>\
<a href="#" id="playlist_item_cancel">NO</a>\
</div>\
';
