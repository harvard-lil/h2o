var dragged_element;
var dropped_item;
var remove_item;
var dropped_original_position;
var items_dd_handles;

$.extend({
  playlist_mark_private: function(user_id, can_edit) {
    $.each($('.private'), function(i, link) {
      var listitem = $(link).parentsUntil('.listitem').last().parent();
      if(user_id != listitem.data('user_id')) {
        listitem.find('.additional_details,div.dd').remove();
        if(!can_edit) {
          listitem.find('.rr').remove();
        }
        var new_html = $(link).html() + ' <span class="private_item">[This resource is private.]</span>';
        $(link).replaceWith(new_html);
      }
    });
    if(can_edit) {
      $('a.private').removeClass('private');
    }
  },
  set_nestability_and_editability: function() {
    if(access_results.is_superadmin) {
      $('li.playlist').data('nestable', true);
    } else if($.cookie('user_id') != null) {
      var editable_playlists = $('li.playlist[data-user_id=' + $.cookie('user_id') + ']');
      editable_playlists.data('nestable', true);
      var editable_items = editable_playlists.find('> .dd > .dd-list > li.listitem');
      var items_to_revoke =  $('li.playlist').not(editable_playlists).not(editable_items);
      items_to_revoke.find('.delete-playlist-item,.edit-playlist-item').remove();
    }
    if(access_results.can_edit) {
      $('div#playlist').data('nestable', true);
    }
  },
  playlist_afterload: function(results) {
    $.set_nestability_and_editability();
    if(results.can_edit || results.can_edit_notes || results.can_edit_desc) {
      if(results.can_edit) {
        $.playlist_mark_private($.cookie('user_id'), true);
        $('.requires_edit, .requires_remove').animate({ opacity: 1.0 }, 400, 'swing', function() {
          $('#description .inactive').css('opacity', 0.4);
        });
        $('#edit_toggle').click();
        is_owner = true;

        if(results.nested_private_count_nonowned > 0 || results.nested_private_count_owned > 0) {
          var data = {
            "owned" : results.nested_private_count_owned,
            "nonowned" : results.nested_private_count_nonowned,
            "url" : '/playlists/' + $('#playlist').data('itemid') + '/toggle_nested_private'
          };
          if(results.nested_private_count_owned == 0) {
            var content = $($.mustache(nested_notification, data)).css('display', 'none');
            content.appendTo($('#description'));
            content.slideDown();
          } else {
            var content = $($.mustache(set_nested_owned_private_resources_public, data)).css('display', 'none');
            content.appendTo($('#description'));
            content.slideDown();
      
            $(document).delegate('#nested_public', 'click', function(e) {
              e.preventDefault();
              var creator = $('#main_details h3 a:first').html().replace(/ \(.*/, '');
              var node = $('<p>').html('You have chosen to set all nested resources owned by ' + creator + ' to public.</p><p><b>Note this will not set items owned by other users to public.</b></p>');
              $(node).dialog({
                title: 'Set Nested Resources to Public',
                width: 'auto',
                height: 'auto',
                buttons: {
                  Yes: function() {
                    $.ajax({
                      type: 'post',
                      dataType: 'json',
                      url: '/playlists/' + $('#playlist').data('itemid') + '/toggle_nested_private',
                      beforeSend: function(){
                        $.showGlobalSpinnerNode();
                      },
                      success: function(data) {
                        $('#nested_public').remove();
                        $('#private_detail').html('There are now ' + data.updated_count + ' nested private items in this playlist, owned by other users.').css('color', 'red');
                        $(node).dialog('close');
                      },
                      complete: function() {
                        $.hideGlobalSpinnerNode();
                      }
                    });
                  },
                  No: function() {
                    $(node).dialog('close');
                  }
                }
              });
            });
          }
        }
      } else {
        $.playlist_mark_private($.cookie('user_id'), false);
        if(!results.can_edit_notes) {
          $('#description #public-notes, #description #private-notes').remove();
        }
        if(!results.can_edit_desc) {
          $('#description .icon-edit').remove();
        }
        $('.requires_remove').remove();
        $('.requires_edit').animate({ opacity: 1.0 }, 400, 'swing', function() {
          $('#description .inactive').css('opacity', 0.4);
        });
      }
    } else {
      $.playlist_mark_private($.cookie('user_id'), false);
      $('.requires_edit, .requires_remove').remove();
    }
    var notes = $.parseJSON(results.notes) || new Array() 
    $.each(notes, function(i, el) {
      if(el.playlist_item.notes != null) {
        var title = el.playlist_item.public_notes ? "Additional Notes" : "Additional Notes (private)";
        var node = $('<div>').html('<b>' + title + ':</b><br />' + el.playlist_item.notes).addClass('notes');
        if(!$('#playlist_item_' + el.playlist_item.id + ' > .wrapper > .inner-wrapper .additional_details').length) {
          $('#playlist_item_' + el.playlist_item.id + ' > .wrapper > .inner-wrapper').append($('<div>').addClass('additional_details'));
          if($('#playlist_item_' + el.playlist_item.id + ' > .wrapper > .inner-wrapper .rr-cell .rr').size() == 0) {
            $('#playlist_item_' + el.playlist_item.id + ' > .wrapper > .inner-wrapper .rr-cell').append($('<a href="#" class="rr rr-closed" id="rr' + el.playlist_item.id + '">Show/Hide More</a>'));
          }
        }
        $('#playlist_item_' + el.playlist_item.id + ' > .wrapper > .inner-wrapper > .additional_details .notes').remove();
        $('#playlist_item_' + el.playlist_item.id + ' > .wrapper > .inner-wrapper > .additional_details').append(node);
      }
    });
    $('.add-popup select option').remove();
  },
  observeViewerToggleEdit: function() {
    $('#edit_toggle,#quickbar_edit_toggle').click(function(e) {
      e.preventDefault();
      $('#edit_item #status_message').remove();
      var el = $(this);
      if($(this).hasClass('edit_mode')) {
        $('#edit_toggle,#quickbar_edit_toggle').removeClass('edit_mode');
        $('body').removeClass('playlist_edit_mode');
        $('#playlist .dd').removeClass('playlists-edit-mode');
        $('#playlist .dd .icon').removeClass('hover');
        if($('#collapse_toggle').hasClass('expanded')) {
          $('#edit_item').hide();
          $('.singleitem').addClass('expanded_singleitem');
        } else {
          $('#edit_item').hide();
          $('#stats').show();
          $.resetRightPanelThreshold();
          $.checkForPanelAdjust();
        }
        $.unObserveDragAndDrop();
      } else {
        $('#edit_toggle,#quickbar_edit_toggle').addClass('edit_mode');
        $('body').addClass('playlist_edit_mode');
        $('#playlist .dd').addClass('playlists-edit-mode');
        $('#playlist .dd .icon').addClass('hover');
        if($('#collapse_toggle').hasClass('expanded')) {
          $('#collapse_toggle').removeClass('expanded');
          $('.singleitem').removeClass('expanded_singleitem');
          $('#edit_item').show();
          $.resetRightPanelThreshold();
        } else {
          $('#stats').hide();
          $('#edit_item').show();
          $.resetRightPanelThreshold();
        }
        $.observeDragAndDrop();
        $.checkForPanelAdjust();
      }
    });
  },
  observeAdditionalDetailsExpansion: function() {
    $('.listitem .wrapper:not(.missing_item)').hoverIntent(function() {
      $(this).find('a.title,a.author_link,a.rr').addClass('hover_link');
      if(!$(this).parent().hasClass('adding-item')) {
        if($('.adding-item').size()) {
          $('.add-popup').hide();
          $('.adding-item').removeClass('adding-item');
        }
        if(!$('div.dd').hasClass('playlists-edit-mode') && !$(this).parent().hasClass('expanded')) {
          $(this).find('.icon').addClass('hover');
        }
      }
    }, function() {
      $(this).find('a.title,a.author_link,a.rr').removeClass('hover_link');
      if(!$('div.dd').hasClass('playlists-edit-mode') && !$(this).parent().hasClass('expanded') && !$(this).parent().hasClass('adding-item')) {
        $(this).find('.icon').removeClass('hover');
      }
    });
  },
  observePlaylistExpansion: function() {
    $(document).delegate(".playlist .rr", 'click', function() {
      $(this).toggleClass('rr-closed');
      var playlist = $(this).parents(".playlist:eq(0)");
      playlist.find('> .wrapper > .inner-wrapper > .additional_details').slideToggle();
      playlist.find('.playlists:eq(0)').slideToggle();
      playlist.toggleClass('expanded');
      return false;
    });
  },
  observeMainPlaylistExpansion: function() {
    var wedge = $('#main-wedge');
    var wedge_hover = "Click to expand all playlist items";
    var wedge_hover_close = "Click to collapse all playlist items";
    wedge.attr('title', wedge_hover);
    wedge.on('click', function() {
      if($(this).hasClass('opened')){
        $('.additional_details').slideUp();
        $('.rr').addClass('rr-closed');
        $('.listitem').removeClass('expanded');
        $('.listitem').find('.playlists:eq(0)').slideUp();
      } else {
        $('.additional_details').slideDown();
        $('.rr-closed').removeClass('rr-closed');
        $('.listitem').addClass('expanded');
        $('.listitem').find('.playlists:eq(0)').slideDown();
      }
      $(this).toggleClass('opened');
      return false;
    });
  },
  update_positions: function(position_data) {
    var check_first = true;
    var prefix = '';
    $.each(position_data, function(index, value) {
      if(check_first && $('#playlist_item_' + index).parents('.playlist').size() > 0) {
        prefix = $('#playlist_item_' + index).parents('.playlist:first').find('.number:first').html() + '.';
        check_first = false;
      }
      var current_val = $('#playlist_item_' + index + ' .number:first').html();
      var new_value = prefix + value;
      if(current_val != new_value) {
        var posn_rep = new RegExp('^' + current_val + '');
        $('#playlist_item_' + index + ' .number').each(function(i, el) {
          $(el).html($(el).html().replace(posn_rep, new_value));
        });
      }
    });
    if($('#playlist .dd-item').size() == 0) {
      $('#playlist .dd-list').addClass('dd-empty');
    }
  },
  observeDeleteNodes: function() {
    $(document).delegate('#playlist .delete-playlist-item', 'click', function(e) {
      $.cancelItemAdd();
      e.preventDefault();
      var listing = $(this).parentsUntil('.listitem').last();
      listing.parent().addClass('listing-with-delete-form');
      var data = { "url" : $(this).attr('href') }; 
      var content = $($.mustache(delete_playlist_item_template, data)).css('display', 'none');
      content.appendTo(listing);
      content.slideDown(200);
    });
  },
  observeEditNodes: function() {
    $(document).delegate('#playlist .edit-playlist-item', 'click', function(e) {
      $.cancelItemAdd();
      e.preventDefault();
      var url = $(this).attr('href');
      var listing = $(this).parentsUntil('.listitem').last();
      listing.parent().addClass('listing-with-edit-form');
      $.ajax({
        cache: false,
        url: url,
        beforeSend: function() {
            $.showGlobalSpinnerNode();
        },
        success: function(html) {
          $.hideGlobalSpinnerNode();
          var content = $(html).css('display', 'none');
          content.appendTo(listing);
          content.slideDown(200);
        },
        error: function(xhr, textStatus, errorThrown) {
          $.hideGlobalSpinnerNode();
        }
      });
    });
  },
  renderPublicPlaylistBehavior: function(data) {
    $('#public-notes span.count span').html(data.public_count + "/" + data.total_count);
    $('#private-notes span.count span').html(data.private_count + "/" + data.total_count);
    if(data.public_count == data.total_count) {
      $('#public-notes').addClass('inactive').css('opacity', 0.4);
    } else {
      $('#public-notes').removeClass('inactive').css('opacity', 1.0);
    }
    if(data.private_count == data.total_count) {
      $('#private-notes').addClass('inactive').css('opacity', 0.4);
    } else {
      $('#private-notes').removeClass('inactive').css('opacity', 1.0);
    }
  },
  renderEditPlaylistItem: function(item) {
	  $('#playlist_item_form').slideUp(200, function() {
      $(this).remove();
    });
    var listitem_wrapper = $('.listitem' + item.id + ' > .wrapper');
    listitem_wrapper.find('a.title').html(item.name);

    //Description changes
    var item_desc = listitem_wrapper.find('.item_desc');
    if(item_desc.size() == 0 && item.description != '') {
      var new_item = $('<div>').attr('class', 'item_desc').html(item.description);
      if(listitem_wrapper.find('.additional_details').size() == 0) {
        listitem_wrapper.find('.rr-cell').append($('<a href="#" class="rr rr-closed" id="rr' + item.id + '">Show/Hide More</a>'));
        var add_details = $('<div>').addClass('additional_details');
        add_details.append(new_item);
        add_details.insertAfter(listitem_wrapper.find('table'));
      } else {
        if(listitem_wrapper.find('.creator_details').size()) {
          new_item.insertAfter(listitem_wrapper.find('.creator_details'));
        } else {
          listitem_wrapper.find('.additional_details').prepend(new_item);
        }
      }
    } else if(item_desc.size() && item.description == '') {
      item_desc.remove();
    } else if(item_desc.size() && item.description != '') {
      item_desc.html(item.description);
    }

    //Notes changes
    var notes_item = listitem_wrapper.find('.notes');
    if(notes_item.size() == 0 && item.notes != '') {
      var notes_title = item.public_notes ? "Additional Notes" : "Additional Notes (private)";
      var new_item = $('<div>').attr('class', 'notes').html('<b>' + notes_title + ':</b><br />' + item.notes);
      if(listitem_wrapper.find('.additional_details').size() == 0) {
        listitem_wrapper.find('.rr-cell').append($('<a href="#" class="rr rr-closed" id="rr' + item.id + '">Show/Hide More</a>'));
        var add_details = $('<div>').addClass('additional_details');
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
      var notes_title = item.public_notes ? "Additional Notes" : "Additional Notes (private)";
      notes_item.html('<b>' + notes_title + ':</b><br />' + item.notes);
    }

    if(listitem_wrapper.find('.additional_details *').size() == 0) {
      listitem_wrapper.find('.rr').remove();
      listitem_wrapper.find('.additional_details').remove();
    }
  },
  renderNewPlaylistItem: function(data) {
    $.ajax({
      type: 'get',
      url: '/playlist_items/' + data.playlist_item_id,
      success: function(response) {
        $('.playlists .dd-list .listing').replaceWith(response);
        $('.requires_edit,.requires_remove,.requires_logged_in').animate({ opacity: 1.0 });
        $('li#playlist_item_' + data.playlist_item_id + ' .dd').nestable({ group: 1 });
        $.update_positions(data.position_data);
        $.set_nestability_and_editability();
      }, 
      error: function() {
        setTimeout(function() {
          document.location.href = $.rootPath() + data.type + '/' + data.playlist_id;
        }, 1000); 
      }
    });
  },
  observeNoteFunctionality: function() {
    $('#public-notes,#private-notes').click(function(e) {
      e.preventDefault();
      if($(this).hasClass('inactive')) {
        return;
      }
      $.showGlobalSpinnerNode();
      var type = $(this).data('type');
      $.ajax({
        type: 'post',
        dataType: 'json',
        url: '/playlists/' + $('#playlist').data('itemid') + '/notes/' + type,
        success: function(results) {
          $.hideGlobalSpinnerNode();
          $.renderPublicPlaylistBehavior(results);
          if(type == 'public') {
            $('.notes b').html('Additional Notes:');
          } else {
            $('.notes b').html('Additional Notes (private):');
          }
        }
      });
    });
  },
  observeStats: function() {
    $('#playlist-stats').click(function() {
      $(this).toggleClass("active");
      if($('#playlist-stats-popup').height() < 400) {
        $('#playlist-stats-popup').css('overflow', 'hidden');
      } else {
        $('#playlist-stats-popup').css('height', 400);
      }
      $('#playlist-stats-popup').slideToggle('fast');
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
	      $('#nestable2 .dd-list li:nth-child(' + dropped_original_position + ')').before(remove_item);
	      remove_item.slideDown(200, function() {
	        remove_item.data('drop', 'new_item');
	      });
	    });
    }
    if($('.listitem #playlist_item_form')) {
	    $('#playlist_item_form').slideUp(200, function() {
        $(this).remove();
      });
    }
  },
  observePlaylistManipulation: function() {
    $(document).delegate('#playlist_item_delete', 'click', function(e) {
      e.preventDefault();
      var destroy_url = $(this).attr('href');
      $.ajax({
        cache: false,
        type: 'POST',
        url: destroy_url,
        dataType: 'JSON',
        data: { '_method' : 'delete' },
        beforeSend: function() {
          $.showGlobalSpinnerNode();
        },
        error: function(xhr) {
          $.hideGlobalSpinnerNode();
        },
        success: function(data) {
          $.renderPublicPlaylistBehavior(data);
	        $('.listing-with-delete-form').slideUp(200, function() {
            $(this).remove();
          });
          $.update_positions(data.position_data);
          $.hideGlobalSpinnerNode();
        }
      });
    });
    $(document).delegate('#playlist_item_submit', 'click', function(e) {
      e.preventDefault();
      var form = $(this).closest('form');
      var new_item = form.hasClass('new');
      form.ajaxSubmit({
        dataType: "JSON",
        beforeSend: function() {
          $.showGlobalSpinnerNode();
        },
        success: function(data) {
          if(data.error) {
            $('#error_block').html(data.message).show();
          } else {
            if(form.hasClass('new')) {
              $.renderPublicPlaylistBehavior(data);
              $.renderNewPlaylistItem(data);
            } else {
              $.renderPublicPlaylistBehavior(data);
              $.renderEditPlaylistItem(data);
            }
          }
          $.hideGlobalSpinnerNode();
        },
        error: function(xhr) {
          $.hideGlobalSpinnerNode();
        }
      });
    });
    $(document).delegate('#playlist_item_cancel', 'click', function(e) {
      e.preventDefault();
      $.cancelItemAdd();
    });
  },
  unObserveDragAndDrop: function() {
    if(access_results.can_position_update) {
      $('.dd-handle').removeClass('dd-handle').addClass('dd-handle-inactive');
    }
  },
  dropActivate: function(working_playlist, playlist_id) {
    if(dropped_item !== undefined) {
      $.cancelItemAdd();
    }

    var position_update = true; 
    var new_item;

    // If playlist has not been nestable yet (e.g. new item), 
    // it neesd to be called and thrown away
    var throwaway_order = working_playlist.nestable('serialize');
    var nested_order = working_playlist.nestable('serialize');

    var positions = new Array();
    $.each(nested_order, function(i, item) {
      if(item.drop == "new_item") {
        position_update = false;
        new_item = item;
      } else {
        positions.push("playlist_item[]=" + item.itemid);
      }
    });
    if(position_update) {
      $.ajax({
        type: 'post',
        dataType: 'json',
        url: '/playlists/' + playlist_id + '/position_update',
        data: {
          playlist_order: positions.join('&')
        },
        beforeSend: function(){
          $.showGlobalSpinnerNode();
        },
        success: function(data) {
          $.update_positions(data);
        },
        complete: function() {
          $.hideGlobalSpinnerNode();
        }
      });
    } else {
	    var url = $.rootPathWithFQDN() + new_item.type + '/' + new_item.id;
      var listing_el = $('#listing_' + new_item.type + '_' + new_item.id);

      dropped_item = listing_el;
      dropped_original_position = new_item.index + 1; 
	    $.ajax({
	      method: 'GET',
	      cache: false,
	      dataType: "html",
	      url: $.rootPath() + 'playlist_items/new',
	      beforeSend: function(){
	           $.showGlobalSpinnerNode();
	      },
	      data: {
          klass: new_item.type,
          id: new_item.id,
	        playlist_id: playlist_id,
          position: working_playlist.find('> .dd-list > .dd-item').index(listing_el) + 1 
	      },
	      success: function(html){
	        $.hideGlobalSpinnerNode();
          var new_content = $(html);
          listing_el.find('.icon').addClass('hover');
          listing_el.append(new_content).css({ height: 'auto', 'border-top': 'none' }).addClass('listing-with-form');
          listing_el.find('.dd-handle').show();
	      }
	    });
    }
  },
  observeDragAndDrop: function() {
    if(access_results.can_position_update) {
      $('.dd-handle-inactive').removeClass('dd-handle-inactive').addClass('dd-handle');
      $('div.dd').nestable({ group: 1 });
      $('.dd-item,div.playlists').on('custom_change', function() {
      });
    }
  },
  initHeaderPagination: function() {
    $(document).delegate('#add_item_results #header a#right_page:not(.inactive)', 'click', function(e) {
      $('.pagination a.next_page').click();
    });
    $(document).delegate('#add_item_results #header a#left_page:not(.inactive)', 'click', function(e) {
      $('.pagination a.prev_page').click();
    });
    return;
  },
  toggleHeaderPagination: function() {
    if($('.pagination a.next_page').size()) {
      $('#add_item_results #header a#right_page').removeClass('inactive');
    } else {
      $('#add_item_results #header a#right_page').addClass('inactive');
    }
    if($('.pagination a.prev_page').size()) {
      $('#add_item_results #header a#left_page').removeClass('inactive');
    } else {
      $('#add_item_results #header a#left_page').addClass('inactive');
    }
    return;
  },
  initKeywordSearch: function() {
    $(document).delegate('#add_item_search', 'click', function(e) {
      e.preventDefault();
      var itemController = $('#add_item_select').val();
      $.ajax({
        method: 'GET',
        url: $.rootPath() + itemController + '/embedded_pager',
        beforeSend: function(){
           $.showGlobalSpinnerNode();
        },
        data: {
          keywords: $('#add_item_term').val(),
          sort: $('#add_item_results .sort select').val() 
        },
        dataType: 'html',
        success: function(html){
          $.hideGlobalSpinnerNode();
          $('#add_item_results').html(html);
          $.toggleHeaderPagination();
          $('div#nestable2').nestable({ group: 1 }); //, maxDepth: 1 });
          $.initializeBarcodes();
          $('#add_item_results .sort select').selectbox({
            className: "jsb", replaceInvisible: true 
          }).change(function() {
            $('#add_item_search').click(); 
          });
        }
      });
    });
  },
  initPlaylistItemPagination: function() {
    $(document).delegate('.pagination a', 'click', function(e) {
      e.preventDefault();
      $.ajax({
        type: 'GET',
        dataType: 'html',
        beforeSend: function(){
         $.showGlobalSpinnerNode();
        },
        data: {
          keywords: $('#add_item_term').val()
        },
        url: $(this).attr('href'),
        success: function(html){
          $.hideGlobalSpinnerNode();
          $('#add_item_results').html(html);
          $.toggleHeaderPagination();
          $('div#nestable2').nestable({ group: 1 }); //, maxDepth: 1 });
          $('#add_item_results .sort select').selectbox({
            className: "jsb", replaceInvisible: true 
          }).change(function() {
            $('#add_item_search').click(); 
          });
        }
      });
    });
  }
});

$(document).ready(function(){
  $.setPlaylistFontHierarchy(14);

  $('.toolbar, .buttons').css('visibility', 'visible');
  $.observeStats();
  $.observeNoteFunctionality();

  /* New Item Search */
  $('#add_item_select').selectbox({
    className: "jsb", replaceInvisible: true 
  });
  $.initKeywordSearch();
  $.initHeaderPagination();
  $.initPlaylistItemPagination();
  /* End New Search */
  
  $.observeEditNodes();
  $.observeDeleteNodes();
  $.observePlaylistManipulation();
  $.observePlaylistExpansion();
  $.observeMainPlaylistExpansion();
  $.observeAdditionalDetailsExpansion();
  $.observeViewerToggleEdit();
});

var delete_playlist_item_template = '\
<div id="playlist_item_form" class="delete">\
<p>Are you sure you want to delete this playlist item?</p>\
<a href="{{url}}" id="playlist_item_delete">YES</a>\
<a href="#" id="playlist_item_cancel">NO</a>\
</div>\
';

var nested_notification = '\
<p id="private_detail">This playlist contains {{nonowned}} private nested resource item(s) owned by other users.</p>\
';
var set_nested_owned_private_resources_public = '\
<p id="private_detail">This playlist contains {{owned}} private nested resource item(s) owned by you, and {{nonowned}} private nested resource item(s) owned by other users.</p>\
<a href="{{url}}" id="nested_public" class="button">Set nested item(s) owned by you to public</a>\
';
