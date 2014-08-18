var dragged_element;
var dropped_item;
var remove_item;
var dropped_original_position;
var items_dd_handles;

h2o_global.playlist_afterload = function(results) {
  playlists_show.set_nestability_and_editability();
  if(!results.can_destroy) {
    $('#description .delete-action').remove();
  }
  if(results.can_edit) {
    playlists_show.playlist_mark_private($.cookie('user_id'), true);
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
        var content = $($.mustache(playlists_show.nested_notification, data)).css('display', 'none');
        content.appendTo($('#description'));
        content.slideDown();
      } else {
        var content = $($.mustache(playlists_show.set_nested_owned_private_resources_public, data)).css('display', 'none');
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
                    h2o_global.showGlobalSpinnerNode();
                  },
                  success: function(data) {
                    $('#nested_public').remove();
                    $('#private_detail').html('There are now ' + data.updated_count + ' nested private items in this playlist, owned by other users. Please refresh the page to see changes.').css('color', 'red');
                    $(node).dialog('close');
                  },
                  complete: function() {
                    h2o_global.hideGlobalSpinnerNode();
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
    playlists_show.playlist_mark_private($.cookie('user_id'), false);
    $('.requires_edit, .requires_remove').remove();
  }
  if($('.right_panel:visible').size() == 0) {
    $('#stats').fadeIn(200, function() {
      h2o_global.resetRightPanelThreshold();
    });
  }
  var notes = $.parseJSON(results.notes) || new Array() 
  $.each(notes, function(i, playlist_item) {
    if(playlist_item.notes != null) {
      var title = playlist_item.public_notes ? "Notes" : "Notes (private)";
      var node = $('<div>').html('<b>' + title + ':</b><br />' + playlist_item.notes).addClass('notes');
      if(!$('#playlist_item_' + playlist_item.id + ' > .wrapper > .inner-wrapper .additional_details').length) {
        $('#playlist_item_' + playlist_item.id + ' > .wrapper > .inner-wrapper').append($('<div>').addClass('additional_details'));
        if($('#playlist_item_' + playlist_item.id + ' > .wrapper > .inner-wrapper .rr-cell .rr').size() == 0) {
          $('#playlist_item_' + playlist_item.id + ' > .wrapper > .inner-wrapper .rr-cell').append($('<a href="#" class="rr rr-closed" id="rr' + playlist_item.id + '">Show/Hide More</a>'));
        }
      }
      $('#playlist_item_' + playlist_item.id + ' > .wrapper > .inner-wrapper > .additional_details .notes').remove();
      $('#playlist_item_' + playlist_item.id + ' > .wrapper > .inner-wrapper > .additional_details').append(node);
    }
  });
  $('.add-popup select option').remove();
};

var playlists_show = {
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
    if(!access_results.is_superadmin && $.cookie('user_id') != null) {
      $.each($('.playlist.listitem:has(ol.dd-list)'), function(i, el) {
        if($(el).data('user_id') != $.cookie('user_id')) {
          $(el).find('> .dd-list .dd-handle').removeClass('dd-handle');
          var html = $(el).html().replace(/<ol/g, '<ul').replace(/<\/ol>/g, '</ul>');
          $(el).html(html);
        }
      });

      var editable_playlists = $('li.playlist[data-user_id=' + $.cookie('user_id') + ']');
      var editable_items = editable_playlists.find('> .dd-list > li.listitem');
      var top_level_items = $('.listitem[data-level=0]');
      var items_to_revoke =  $('li.listitem').not(top_level_items).not(editable_playlists).not(editable_items);
      items_to_revoke.find('.delete-playlist-item,.edit-playlist-item').remove();
    }
  },
  observeViewerToggleEdit: function() {
    $('#edit_toggle,#quickbar_edit_toggle').click(function(e) {
      e.preventDefault();
      $('#edit_item #status_message').remove();
      var el = $(this);
      if($(this).hasClass('edit_mode')) {
        $('#edit_toggle,#quickbar_edit_toggle').removeClass('edit_mode');
        $('body').removeClass('playlist_edit_mode');
        $('div.main_playlist').removeClass('playlists-edit-mode');
        $('#playlist .dd .icon').removeClass('hover');
        if($('#collapse_toggle').hasClass('expanded')) {
          $('#edit_item').hide();
          $('.singleitem').addClass('expanded_singleitem');
        } else {
          $('#edit_item').hide();
          $('#stats').show();
          h2o_global.resetRightPanelThreshold();
          h2o_global.checkForPanelAdjust();
        }
        playlists_show.unObserveDragAndDrop();
      } else {
        $('#edit_toggle,#quickbar_edit_toggle').addClass('edit_mode');
        $('body').addClass('playlist_edit_mode');
        $('div.main_playlist').addClass('playlists-edit-mode');
        $('#playlist .dd .icon').addClass('hover');
        if($('#collapse_toggle').hasClass('expanded')) {
          $('#collapse_toggle').removeClass('expanded');
          $('.singleitem').removeClass('expanded_singleitem');
          $('#edit_item').show();
          h2o_global.resetRightPanelThreshold();
        } else {
          $('#stats').hide();
          $('#edit_item').show();
          h2o_global.resetRightPanelThreshold();
        }
        playlists_show.observeDragAndDrop();
        h2o_global.checkForPanelAdjust();
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
        if(!$('div.main_playlist').hasClass('playlists-edit-mode') && !$(this).parent().hasClass('expanded')) {
          $(this).find('.icon').addClass('hover');
        }
      }
    }, function() {
      $(this).find('a.title,a.author_link,a.rr').removeClass('hover_link');
      if(!$('div.main_playlist').hasClass('playlists-edit-mode') && !$(this).parent().hasClass('expanded') && !$(this).parent().hasClass('adding-item')) {
        $(this).find('.icon').removeClass('hover');
      }
    });
  },
  observePlaylistExpansion: function() {
    $(document).delegate(".listitem .rr", 'click', function() {
      $(this).toggleClass('rr-closed');
      var playlist = $(this).parents(".listitem:eq(0)");
      playlist.find('> .wrapper > .additional_details').slideToggle();
      playlist.find('.dd-list:eq(0)').slideToggle();
      playlist.toggleClass('expanded');
      return false;
    });
  },
  observeMainPlaylistExpansion: function() {
    var wedge_hover = "Click to expand all playlist items";
    var wedge_hover_close = "Click to collapse all playlist items";
    $('#main-wedge').attr('title', wedge_hover).on('click', function() {
      if($(this).hasClass('opened')){
        $('.additional_details').slideUp();
        $('.rr').addClass('rr-closed');
        $('.listitem').removeClass('expanded');
        $('.listitem').find('.dd-list:eq(0)').slideUp();
      } else {
        $('.additional_details').slideDown();
        $('.rr-closed').removeClass('rr-closed');
        $('.listitem').addClass('expanded');
        $('.listitem').find('.dd-list:eq(0)').slideDown();
      }
      $(this).toggleClass('opened');
      return false;
    });
  },
  set_last_items: function() {
    $('li.last').removeClass('last');
    $.each($('.dd-list'), function(i, el) {
      $(el).find('> li:last').addClass('last');
    });
  },
  update_positions: function() {
    var level = 0;
    while($('.listitem[data-level="' + level + '"]').size()) {
      $.each($('.listitem[data-level="' + level + '"]'), function(i, el) {
        var prefix = '';
        var counter_start = $('div.main_playlist').data('counter_start');
        if($(el).parents('.listitem').size()) {
          prefix = $(el).parents('.listitem:first').find('.number:first').html() + '.';
          counter_start = $(el).parents('.dd-list:first').data('counter_start');
        }
        var index = $(el).parent().find('> li').index($(el));
        $(el).data('position', index);
        var new_value = prefix + (index + counter_start);
        $(el).find('.number').html(new_value);
      });
      level += 1;
    }
    playlists_show.set_last_items();
  },
  observeDeleteNodes: function() {
    $(document).delegate('#playlist .delete-playlist-item', 'click', function(e) {
      playlists_show.cancelItemAdd();
      e.preventDefault();
      var listing = $(this).parentsUntil('.listitem').last();
      listing.parent().addClass('listing-with-delete-form');
      var data = { "url" : $(this).attr('href') }; 
      var content = $($.mustache(playlists_show.delete_playlist_item_template, data)).css('display', 'none');
      content.appendTo(listing);
      content.slideDown(200);
    });
  },
  observeEditNodes: function() {
    $(document).delegate('#playlist .edit-playlist-item', 'click', function(e) {
      playlists_show.cancelItemAdd();
      e.preventDefault();
      var url = $(this).attr('href');
      var listing = $(this).parentsUntil('.listitem').last();
      listing.parent().addClass('listing-with-edit-form');
      $.ajax({
        cache: false,
        url: url,
        beforeSend: function() {
            h2o_global.showGlobalSpinnerNode();
        },
        success: function(html) {
          h2o_global.hideGlobalSpinnerNode();
          var content = $(html).css('display', 'none');
          content.appendTo(listing);
          content.slideDown(200);
        },
        error: function(xhr, textStatus, errorThrown) {
          h2o_global.hideGlobalSpinnerNode();
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
  observeNoteFunctionality: function() {
    $('#public-notes,#private-notes').click(function(e) {
      e.preventDefault();
      if($(this).hasClass('inactive')) {
        return;
      }
      h2o_global.showGlobalSpinnerNode();
      var type = $(this).data('type');
      $.ajax({
        type: 'post',
        dataType: 'json',
        url: '/playlists/' + $('#playlist').data('itemid') + '/' + type + '_notes',
        success: function(results) {
          h2o_global.hideGlobalSpinnerNode();
          playlists_show.renderPublicPlaylistBehavior(results);
          if(type == 'public') {
            $('.notes b').html('Notes:');
          } else {
            $('.notes b').html('Notes (private):');
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
          h2o_global.showGlobalSpinnerNode();
        },
        error: function(xhr) {
          h2o_global.hideGlobalSpinnerNode();
        },
        success: function(data) {
          playlists_show.renderPublicPlaylistBehavior(data);
          $('.listing-with-delete-form').slideUp(200, function() {
            $(this).remove();
            playlists_show.update_positions();
            if($('div.main_playlist li').size() == 0) {
              $('div.main_playlist > .dd-list').addClass('dd-empty');
            }
          });
          h2o_global.hideGlobalSpinnerNode();
        }
      });
    });
    $(document).delegate('#playlist_item_submit', 'click', function(e) {
      e.preventDefault();
      var form = $(this).closest('form');
      form.append($('<input>').attr('name', 'on_playlist_page').attr('type', 'hidden').val(1));
      var new_item = form.hasClass('new');
      form.ajaxSubmit({
        dataType: "JSON",
        beforeSend: function() {
          h2o_global.showGlobalSpinnerNode();
        },
        success: function(data) {
          if(data.error) {
            $('#error_block').html(data.message).show();
          } else {
            playlists_show.renderPublicPlaylistBehavior(data);
            if(form.hasClass('new')) {
              var new_node = $(data.content);
              new_node.find('.requires_edit,.requires_remove,.requires_logged_in').css('opacity', 1);
              new_node.find('.icon-cell .tooltip').addClass('hover');
              $('.playlists .dd-list .listing').replaceWith(new_node);
            } else {
              var new_node = $(data.content).find('.wrapper');
              new_node.find('.requires_edit,.requires_remove,.requires_logged_in').css('opacity', 1);
              new_node.find('.icon-cell .tooltip').addClass('hover');
              $('#playlist_item_form').parent().replaceWith(new_node);
            }
            playlists_show.update_positions();
            playlists_show.set_nestability_and_editability();
            dropped_item = undefined;
          }
          h2o_global.hideGlobalSpinnerNode();
        },
        error: function(xhr) {
          h2o_global.hideGlobalSpinnerNode();
        }
      });
    });
    $(document).delegate('#playlist_item_cancel', 'click', function(e) {
      e.preventDefault();
      playlists_show.cancelItemAdd();
    });
  },
  unObserveDragAndDrop: function() {
    if(access_results.can_edit) {
      $('.dd-handle').removeClass('dd-handle').addClass('dd-handle-inactive');
    }
  },
  dropActivate: function() {
    if(dropped_item !== undefined) {
      playlists_show.cancelItemAdd();
    }

    if($('div.main_playlist .dd-item[data-drop="new_item"]').size()) {
      var new_item = $('div.main_playlist .dd-item[data-drop="new_item"]');
      var listing_el = $('#listing_' + new_item.data('type') + '_' + new_item.data('id'));
      var playlist_id = $('div.main_playlist').data('playlist_id');
      if(new_item.parents('.listitem:first').size()) {
        playlist_id = new_item.parents('.listitem:first').data('actual_object_id')
        if(new_item.parents('.listitem:first').find('ol').size() == 0) {
          dropped_item = undefined;
          new_item.remove();
          return;
        }
      }

      dropped_item = listing_el;
      dropped_original_position = new_item.index + 1; 
      $.ajax({
        method: 'GET',
        cache: false,
        dataType: "html",
        url: h2o_global.root_path() + 'playlist_items/new',
        beforeSend: function(){
             h2o_global.showGlobalSpinnerNode();
        },
        data: {
          klass: new_item.data('type'),
          id: new_item.data('id'),
          playlist_id: playlist_id,
          position: new_item.parent().find('> li').index(new_item)
        },
        success: function(html){
          h2o_global.hideGlobalSpinnerNode();
          var new_content = $(html);
          listing_el.find('.icon').addClass('hover');
          listing_el.append(new_content).css({ height: 'auto', 'border-top': 'none' }).addClass('listing-with-form');
          listing_el.find('.dd-handle').show();
        }
      });
    } else {
      var changed = playlists_show.identifyChangedPositions($('div.main_playlist').nestable('serialize'), 0);
      if(changed.length == 0) {
        return;
      }
      $.ajax({
        type: 'post',
        dataType: 'json',
        url: '/playlists/' + h2o_global.getItemId() + '/position_update',
        data: {
          changed: changed
        },
        beforeSend: function(){
          h2o_global.showGlobalSpinnerNode();
        },
        success: function(data) {
          playlists_show.update_positions();
        },
        complete: function() {
          h2o_global.hideGlobalSpinnerNode();
        }
      });
    }
  },
  identifyChangedPositions: function(data, level) {
    var changed = [];
    $.each(data, function(i, b) {
      if(b.position != i || level != b.level) {
        var playlist_id = $('#playlist_item_' + b.itemid).parent().parent().data('actual_object_id');
        if(b.itemid !== undefined) {
          changed.push({ id: b.itemid, position: i, playlist_id: playlist_id })
        }
      }
      if(b.children !== undefined) {
        var nested_changed = playlists_show.identifyChangedPositions(b.children, (level + 1));
        $.each(nested_changed, function(x, y) {
          changed.push(y);
        });
      }
    });
    return changed;
  },
  observeDragAndDrop: function() {
    if(access_results.can_edit) {
      $('.dd-handle-inactive').removeClass('dd-handle-inactive').addClass('dd-handle');
      $('div.main_playlist').nestable();
      $('div.main_playlist').on('change', function(el) {
        if(!$(el.target).hasClass('dd-nodrag')) {
          playlists_show.dropActivate();
        }
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
    $('ul#klass_filters a,ul#user_id_filters a:not(#load_more_users)').live('click', function(e) {
      e.preventDefault();
      $(this).addClass('active');
      $('#add_item_search').click();
    });
    $('.clear_filters').live('click', function(e) {
      e.preventDefault();
      $(this).parent().siblings('ul').find('a.active').removeClass('active');
      $('#add_item_search').click();
    });
    $('#search_within').live('click', function(e) {
      e.preventDefault();
      $('#add_item_search').click();
    });
    $(document).delegate('#add_item_search', 'click', function(e) {
      e.preventDefault();
      var itemController = $('#add_item_select').val();

      data = {
          keywords: $('#add_item_term').val(),
          sort: $('#add_item_results .sort select').val(),
      };
      if($('ul#user_id_filters a.active').size()) {
        data.user_ids = $('ul#user_id_filters a.active').data('value');
      }
      if($('ul#klass_filters a.active').size()) {
        data.klass = $('ul#klass_filters a.active').data('value');
      }
      if($('input[name=within]').size() && $('input[name=within]').val() != '') {
        data.within = escape($('input[name=within]').val());
      }

      $.ajax({
        method: 'GET',
        url: h2o_global.root_path() + itemController + '/embedded_pager',
        beforeSend: function(){
           h2o_global.showGlobalSpinnerNode();
        },
        data: data,
        dataType: 'html',
        success: function(html){
          h2o_global.hideGlobalSpinnerNode();
          $('#add_item_results').html(html);
          playlists_show.toggleHeaderPagination();
          $('div#nestable2').nestable();

          $('#new_playlist_drilldown #search_within').html('Apply');
          $('#playlist_drilldown').html($('#new_playlist_drilldown').html());
          $('#new_playlist_drilldown').remove();
          if($('#playlist_drilldown #within input').val() == '') {
            $('#playlist_drilldown #within input').val('Filter by Keyword or Name');
          }
          if($('#user_id_filters').size()) {
            user_drilldown = $('#user_id_filters').data('users');
          }

          $('#add_item_results .sort select').selectbox({
            className: "jsb", replaceInvisible: true 
          }).change(function() {
            $('#add_item_search').click(); 
          });
        }
      });
    });
    $(document).delegate('#playlist_drilldown #within input', 'focus', function() {
      if($(this).val() == 'Filter by Keyword or Name') {
        $(this).val('');
      }
    });
    $(document).delegate('#playlist_drilldown #within input', 'blur', function() {
      if($(this).val() == '') {
        $(this).val('Filter by Keyword or Name');
      }
    });
  },
  initPlaylistItemPagination: function() {
    $(document).delegate('.pagination a', 'click', function(e) {
      e.preventDefault();
      $.ajax({
        type: 'GET',
        dataType: 'html',
        beforeSend: function(){
         h2o_global.showGlobalSpinnerNode();
        },
        data: {
          keywords: $('#add_item_term').val()
        },
        url: $(this).attr('href'),
        success: function(html){
          h2o_global.hideGlobalSpinnerNode();
          $('#add_item_results').html(html);
          playlists_show.toggleHeaderPagination();
          $('div#nestable2').nestable();
          $('#add_item_results .sort select').selectbox({
            className: "jsb", replaceInvisible: true 
          }).change(function() {
            $('#add_item_search').click(); 
          });
        }
      });
    });
  },
  initialize: function() {
    h2o_global.setPlaylistFontHierarchy(14);
  
    $('.toolbar, .buttons').css('visibility', 'visible');
    playlists_show.observeStats();
    playlists_show.observeNoteFunctionality();
  
    $('#add_item_select').selectbox({
      className: "jsb", replaceInvisible: true 
    });
    playlists_show.set_last_items();
    playlists_show.initKeywordSearch();
    playlists_show.initHeaderPagination();
    playlists_show.initPlaylistItemPagination();
    playlists_show.observeEditNodes();
    playlists_show.observeDeleteNodes();
    playlists_show.observePlaylistManipulation();
    playlists_show.observePlaylistExpansion();
    playlists_show.observeMainPlaylistExpansion();
    playlists_show.observeAdditionalDetailsExpansion();
    playlists_show.observeViewerToggleEdit();
  },
  nested_notification: '<p id="private_detail">This playlist contains {{nonowned}} private nested resource item(s) owned by other users.</p>',
  set_nested_owned_private_resources_public: '\
<p id="private_detail">This playlist contains {{owned}} private nested resource item(s) owned by you, and {{nonowned}} private nested resource item(s) owned by other users.</p>\
<a href="{{url}}" id="nested_public" class="button">Set nested item(s) owned by you to public</a>',
  delete_playlist_item_template: '\
<div id="playlist_item_form" class="delete">\
<p>Are you sure you want to delete this playlist item?</p>\
<a href="{{url}}" id="playlist_item_delete" class="dd-nodrag">YES</a>\
<a href="#" id="playlist_item_cancel" class="dd-nodrag">NO</a>\
</div>'
};
