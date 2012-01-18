var popup_item_id = 0;
var popup_item_type = '';

$.noConflict();

jQuery.extend({
  classType: function() {
    return jQuery('body').attr('id').replace(/^b/, '');
  },
  rootPath: function(){
    return '/';
  },
  loadEditability: function() {
    jQuery.ajax({
      type: 'GET',
      cache: false,
      url: editability_path,
      dataType: "JSON",
      beforeSend: function(){
        jQuery.showGlobalSpinnerNode();
      },
      error: function(xhr){
        jQuery.hideGlobalSpinnerNode();
        jQuery('.requires_edit').remove();
        jQuery('.requires_logged_in').remove();
        jQuery('.afterload').animate({ opacity: 1.0 });
        jQuery.hideGlobalSpinnerNode();
		    jQuery.loadState();
      },
      success: function(results){
        if(results.can_edit) {
          jQuery('.requires_edit').animate({ opacity: 1.0 });
          is_owner = true;
        } else {
          jQuery('.requires_edit').remove();
        }
        if(results.logged_in) {
          var data = jQuery.parseJSON(results.logged_in);
          jQuery('.requires_logged_in .user_account').append(jQuery('<a>').html(data.user.login).attr('href', "/users/" + data.user.id));
          jQuery('.requires_logged_in').animate({ opacity: 1.0 });
          jQuery('#header_login').remove();
        } else {
          jQuery('.requires_logged_in').remove();
        }
        jQuery('.afterload').animate({ opacity: 1.0 });
        jQuery.hideGlobalSpinnerNode();
        if(jQuery.classType() == 'collages') {
		      jQuery.loadState();
          if(is_owner) {
			      jQuery.listenToRecordCollageState();
          }
        } else if(jQuery.classType() == 'playlists') {
          var notes = jQuery.parseJSON(results.notes); 
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
          var playlists = jQuery.parseJSON(results.playlists); 
          jQuery.each(playlists, function(i, el) {
            var node = jQuery('<option>').val(el.playlist.id).text(el.playlist.name);
            jQuery('.add-popup select').append(node);
          });
          jQuery.observeDragAndDrop();
        }
      }
    });
  },
  initializeTabBehavior: function() {
    jQuery('.tabs a').click(function(e) {
      var region = jQuery(this).data('region');
      jQuery('.add-popup').hide();
      popup_item_id = 0;
      popup_item_type = '';
      jQuery('.tabs a').removeClass("active");
      jQuery('.songs > ul').hide();
      jQuery('.pagination > div, .sort > div').hide();
      jQuery('#' + region +
        ',.' + region + '_pagination' +
        ',#' + region + '_sort').show();
      jQuery(this).addClass("active");
      e.preventDefault();
    });
    //TODO: Possibly generic-ize this later if more of this
    //functionality is needed. For now it's only needed
    //on bookmarks
    if(document.location.hash == '#vbookmarks') {
      jQuery('#bookmark_tab').click();
    } else {
      jQuery('.tabs a:first').click();
    }
  },
  observeLoginPanel: function() {
    jQuery('#header_login').click(function(e) {
      jQuery(this).toggleClass('active');
      jQuery('#login-popup').toggle();
      e.preventDefault();
    });
  },
  observeCasesCollage: function() {
    jQuery('.case_collages').click(function(e) {
      e.preventDefault();
      jQuery('#collages' + jQuery(this).data('id')).toggle();
      jQuery(this).toggleClass('active');
    });
    jQuery('.hide_collages').click(function(e) {
      e.preventDefault();
      jQuery('#collages' + jQuery(this).data('id')).toggle();
      jQuery(this).parent().siblings('.cases_details').find('.case_collages').removeClass('active');
    });
  },
  addItemToPlaylistDialog: function(itemController, itemName, itemId, playlistId) {
    var url_string = jQuery.rootPathWithFQDN() + itemController + '/' + itemId;
    if(!url_string.match(/\/[0-9]+$/)) {
      url_string = itemId;
    }
    jQuery.ajax({
      method: 'GET',
      cache: false,
      dataType: "html",
      url: jQuery.rootPath() + 'item_' + itemController + '/new',
      beforeSend: function(){
           jQuery.showGlobalSpinnerNode();
      },
      data: {
        url_string: url_string,
        container_id: playlistId
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
  },
  observeMarkItUpFields: function() {
    jQuery('.textile_description').observeField(5,function(){
        jQuery.ajax({
        cache: false,
        type: 'POST',
        url: jQuery.rootPath() + 'collages/description_preview',
        data: {
            preview: jQuery('.textile_description').val()
        },
           success: function(html){
            jQuery('.textile_preview').html(html);
        }
        });
    });
    },

  observeTabDisplay: function(region) {
    jQuery(region + ' .link-add a').click(function() {
      var element = jQuery(this);
      var current_id = element.data('item_id');
      if(popup_item_id != 0 && current_id == popup_item_id) {
        jQuery('.add-popup').hide();
        popup_item_id = 0;
      } else {
        popup_item_id = current_id;
        popup_item_type = element.data('type');
        var position = element.offset();
        var results_posn = jQuery('.add-popup').parent().offset();
        var left = position.left - results_posn.left;
        jQuery('.add-popup').hide().css({ top: position.top + 24, left: left }).fadeIn(100);
      }

      return false;
    });
    jQuery('.new-playlist-item').click(function(e) {
      var itemName = popup_item_type.charAt(0).toUpperCase() + popup_item_type.slice(1);
      jQuery.addItemToPlaylistDialog(popup_item_type + 's', itemName, popup_item_id, jQuery('#playlist_id').val()); 
      e.preventDefault();
    });
  },
  listResults: function(href, region) {
    jQuery.ajax({
      type: 'GET',
      dataType: 'html',
      url: href,
      beforeSend: function(){
           jQuery.showGlobalSpinnerNode();
         },
         error: function(xhr){
           jQuery.hideGlobalSpinnerNode();
      },
      success: function(html){
        jQuery.address.value(href);
        jQuery.hideGlobalSpinnerNode();
        if(jQuery('#bbase').length || jQuery('#busers').length) {
          jQuery(region).html(html);
          var class_region = region.replace(/^#/, '.');
          jQuery(class_region + '_pagination').html(jQuery(region + ' #new_pagination').html()); 
        } else {
          jQuery(region).html(html);
          jQuery('.pagination').html(jQuery(region + ' #new_pagination').html());
        }
        //Here we need to re-observe onclicks
        jQuery.observePagination(); 
        jQuery.observeTabDisplay(region);
        jQuery.observeCasesCollage();
      }
    });
  },
  observeSort: function() {
    jQuery('.sort-asc,.sort-desc').click(function(e) {
      e.preventDefault();
      var data = {};
      var region = '#all_' + jQuery.classType();
      if(jQuery('#bbase').length || jQuery('#busers').length) {
        region = '#' + jQuery('.songs > ul:visible').attr('id');
      }
      var ajax_region = region.replace(/#all_/, '');
      var sort = jQuery(this).parent().parent().find('select').val();

      var url = document.location.pathname;
      if(document.location.search != '') {
        url += document.location.search + "&ajax_region=" + ajax_region + "&sort=" + sort + "&order=" + jQuery(this).data('val');
      } else {
        url += "?ajax_region=" + ajax_region + "&sort=" + sort + "&order=" + jQuery(this).data('val');
      }
      jQuery.listResults(url, region);
    });
    jQuery('.sort select').selectbox({
      className: "jsb", replaceInvisible: true 
    }).change(function() {
      var region = '#all_' + jQuery.classType();
      if(jQuery('#bbase').length || jQuery('#busers').length) {
        region = '#' + jQuery('.songs > ul:visible').attr('id');
      }
      var sort = jQuery(this).val();
      var ajax_region = region.replace(/^#all_/, '');
      var url = document.location.pathname;
      if(document.location.search != '') {
        url += document.location.search + "&ajax_region=" + ajax_region + "&sort=" + sort;
      } else {
        url += "?ajax_region=" + ajax_region + "&sort=" + sort;
      }
      jQuery.listResults(url, region);
    });
  },
  observePagination: function(){
    jQuery('.pagination a').click(function(e){
      e.preventDefault();
      var region = '#all_' + jQuery.classType();
      if(jQuery('#bbase').length || jQuery('#busers').length) {
        region = '#all_' + jQuery(this).closest('div').data('type');
      }
      jQuery.listResults(jQuery(this).attr('href'), region);
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
    return location.protocol + '//' + location.hostname + ((location.port == '' || location.port == 80 || location.port == 443) ? '' : ':' + location.port) + '/';
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
    return jQuery(".singleitem").data("itemid");
  },

  /* 
  This is a generic UI function that applies to all elements with the "delete-action" class.
  With this, a dialog box is generated that asks the user if they want to delete the item (Yes, No).
  When a user clicks "Yes", an ajax call is made to the link's href, which responds with JSON.
  The listed item is then removed from the UI.
  */
  observeDestroyControls: function(region){
      jQuery(region + ' .delete-action').live('click', function(e){
      var destroyUrl = jQuery(this).attr('href');
      var item_id = destroyUrl.match(/[0-9]+$/).toString();
      e.preventDefault();
      var confirmNode = jQuery('<div><p>Are you sure you want to delete this item?</p></div>');
      jQuery(confirmNode).dialog({
          modal: true,
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
                jQuery(".listitem" + item_id).animate({ opacity: 0.0, height: 0 }, 500, function() {
                  jQuery(".listitem" + item_id).remove();
                });
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
      var item_url = jQuery.rootPathWithFQDN() + 'bookmark_item/';
      var el = jQuery(this);
      if(el.hasClass('bookmark-popup')) {
        item_url += popup_item_type + '/' + popup_item_id;
      } else {
        item_url += jQuery.classType() + '/' + jQuery('.singleitem').data('itemid');
      }
      e.preventDefault();
      jQuery.ajax({
        cache: false,
        url: item_url,
        dataType: "JSON",
        data: {},
        beforeSend: function() {
            jQuery.showGlobalSpinnerNode();
        },
        success: function(data) {
          jQuery('.add-popup').hide();
          jQuery.hideGlobalSpinnerNode();
          var snode;
          if(data.already_bookmarked) {
            snode = jQuery('<span class="bookmarked">').html('ALREADY BOOKMARKED!').append(
              jQuery('<a>').attr('href', jQuery.rootPathWithFQDN() + 'users/' + data.user_id + '#vbookmarks').html('VIEW BOOKMARKS'));
          } else {
            snode = jQuery('<span class="bookmarked">').html('BOOKMARKED!').append(
              jQuery('<a>').attr('href', jQuery.rootPathWithFQDN() + 'users/' + data.user_id + '#vbookmarks').html('VIEW BOOKMARKS'));
          }

          if(el.hasClass('bookmark-popup')) {
            if(jQuery.classType() == 'users' && jQuery('#bookmark_tab').hasClass('active')) {
              snode.html('ALREADY BOOKMARKED!');
              jQuery('hgroup.' + popup_item_type + popup_item_id + ' .bookmarked').remove();
              snode.insertBefore(jQuery('hgroup.' + popup_item_type + popup_item_id + ' .cl'));
            } else if(jQuery.classType() == 'playlists' && jQuery('.singleitem').size() && popup_item_type != 'default') {
              jQuery('hgroup.' + popup_item_type + popup_item_id + ' .bookmarked').remove();
              snode.insertBefore(jQuery('hgroup.' + popup_item_type + popup_item_id + ' .cl'));
            } else {
              jQuery('.listitem' + popup_item_id + ' h4 .bookmarked').remove();
              jQuery('.listitem' + popup_item_id + ' h4').append(snode);
            }
          } else {
            jQuery('.singleitem > .description > h2 .bookmarked,#fixed_header > .description > h2 .bookmarked').remove();
            jQuery('.singleitem > .description > h2,#fixed_header > .description h2').append(snode);
          }
        },
        error: function(xhr, textStatus, errorThrown) {
            jQuery.hideGlobalSpinnerNode();
        }
      });
    });
  },

  /* New Playlist and Add Item */
  observeNewPlaylistAndItemControls: function() {
      jQuery('.new-playlist-and-item').live('click', function(e){
      var item_id = popup_item_id;
      var actionUrl = jQuery(this).attr('href');
      e.preventDefault();
      jQuery.ajax({
        cache: false,
        url: actionUrl,
        beforeSend: function() {
            jQuery.showGlobalSpinnerNode();
        },
        success: function(html) {
            jQuery.hideGlobalSpinnerNode();
          jQuery.generateSpecialPlaylistNode(html);
        },
        error: function(xhr, textStatus, errorThrown) {
            jQuery.hideGlobalSpinnerNode();
        }
      });
    });
  },
  generateSpecialPlaylistNode: function(html) {
    var newItemNode = jQuery('<div id="special-node"></div>').html(html);
    var title = '';
    if(newItemNode.find('#generic_title').length) {
      title = newItemNode.find('#generic_title').html();
    }
    jQuery(newItemNode).dialog({
      title: title,
      modal: true,
      width: 'auto',
      height: 'auto',
      open: function(event, ui) {
        jQuery.observeMarkItUpFields();
      },
      close: function() {
        jQuery(newItemNode).remove();
      },
      buttons: {
        Submit: function() {
          jQuery('#special-node').find('form').ajaxSubmit({
            dataType: "JSON",
            beforeSend: function() {
              jQuery.showGlobalSpinnerNode();
            },
            success: function(data) {
              jQuery(newItemNode).dialog('close');
              var itemName = popup_item_type.charAt(0).toUpperCase() + popup_item_type.slice(1);
              jQuery.addItemToPlaylistDialog(popup_item_type + 's', itemName, popup_item_id, data.id);
            },
            error: function(xhr) {
              jQuery.hideGlobalSpinnerNode();
            }
          });
        },
        Close: function() {
          jQuery(newItemNode).remove();
        }
      }
    }).dialog('open');
  },

  /* Generic HTML form elements */
  observeGenericControls: function(region){
      jQuery(region + ' .remix-action,' + region + ' .edit-action,' + region + ' .new-action').live('click', function(e){
      var actionUrl = jQuery(this).attr('href');
      e.preventDefault();
      jQuery.ajax({
        cache: false,
        url: actionUrl,
        beforeSend: function() {
            jQuery.showGlobalSpinnerNode();
        },
        success: function(html) {
            jQuery.hideGlobalSpinnerNode();
          jQuery.generateGenericNode(html);
        },
        error: function(xhr, textStatus, errorThrown) {
            jQuery.hideGlobalSpinnerNode();
        }
      });
    });
  },
  generateGenericNode: function(html) {
    var newItemNode = jQuery('<div id="generic-node"></div>').html(html);
    var title = '';
    if(newItemNode.find('#generic_title').length) {
      title = newItemNode.find('#generic_title').html();
    }
    jQuery(newItemNode).dialog({
      title: title,
      modal: true,
      width: 'auto',
      height: 800,
      open: function(event, ui) {
        jQuery.observeMarkItUpFields();
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
        document.location.href = jQuery.rootPath() + data.type + '/' + data.id;
      },
      error: function(xhr) {
        jQuery.hideGlobalSpinnerNode();
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
    //initDiscussionControls();

  jQuery("#search .btn-tags").click(function() {
    var $p = jQuery(".browse-tags-popup");
    
    $p.toggle();
    jQuery(this).toggleClass("active");
    
    return false;
  });
  
  jQuery(".playlist .data .dd").click(function() {
    jQuery(this).toggleClass('dd-closed');
    jQuery(this).siblings('.item_description').slideToggle();
    jQuery(this).parents(".playlist:eq(0)").find(".playlists:eq(0)").slideToggle();
    var open = new Array;
    jQuery('.playlist .data .dd').not('.dd-closed').each(function(i, el) {
      open.push(jQuery(el).attr('id'));
    });  
    jQuery.cookie('expanded', open.join('-'));
    return false;
  });
  
  jQuery("#search input[type=radio]").click(function() {
    jQuery("#search form").attr("action", "/" + jQuery(this).val());
  });
  if(jQuery('#radios input[value=' + jQuery.classType() + ']').length) {
    jQuery('#radios input[value=' + jQuery.classType() + ']').click();
  } else {
    jQuery("#search_all_radio").click();
  }

  jQuery(".link-more,.link-less").click(function(e) {
    jQuery("#description_less,#description_more").toggle();
    e.preventDefault();
  });

  jQuery('.item_drag_handle').button({icons: {primary: 'ui-icon-arrowthick-2-n-s'}});

  jQuery('.link-copy').click(function() {
    jQuery(this).closest('form').submit();
  });
  //jQuery('#results .song details .influence input').rating();
  //jQuery('#playlist details .influence input').rating();

  jQuery('li.submit a').click(function() {
    jQuery('form.search').submit();
  });

  /* End TODO */

  jQuery.observeDestroyControls('');
  jQuery.observeGenericControls('');
  jQuery.observeBookmarkControls('');
  jQuery.observeNewPlaylistAndItemControls();
  jQuery.observePagination(); 
  jQuery.observeSort();
  jQuery.observeTabDisplay('');
  jQuery.observeCasesCollage();
  jQuery.observeLoginPanel();
  jQuery.initializeTabBehavior();

  if(document.location.hash.match('ajax_region=') || document.location.hash.match('page=')) {
    var region = '#all_' + jQuery.classType();
    if(jQuery('#bbase').length || jQuery('#busers').length) {
      region = '#all_' + jQuery.address.parameter('ajax_region');
      jQuery('.tabs a').each(function(i, el) {
        if('#' + jQuery(el).data('region') == region) {
          jQuery(el).click();
        }
      });
    }
    jQuery.listResults(jQuery.address.value(), region);
  }

  var expanded_v = jQuery.cookie('expanded');
  if(expanded_v != null) {
    var expanded = expanded_v.split('-');
    for(var i=0;i<expanded.length;i++) {
      jQuery('#' + expanded[i]).click();
    }
  } 

  //For Now, this is disabled. If set to true,
  //code updates are required to work with back button
  //on each pagination and sort
  jQuery.address.history(false);
});
// -------------------------------------------------------------------
// markItUp!
// -------------------------------------------------------------------
// Copyright (C) 2008 Jay Salvat
// http://markitup.jaysalvat.com/
// -------------------------------------------------------------------
// Textile tags example
// http://en.wikipedia.org/wiki/Textile_(markup_language)
// http://www.textism.com/
// -------------------------------------------------------------------
// Feel free to add more tags
// -------------------------------------------------------------------
var h2oTextileSettings = {
  nameSpace: 'textile',
  previewParserPath:	'/base/preview_textile_content',
  previewAutoRefresh: true,
  onShiftEnter:		{keepDefault:false, replaceWith:'\n\n'},
  markupSet: [
    {name:'Bold', key:'B', closeWith:'*', openWith:'*'},
    {name:'Underline', key:'U', closeWith:'_', openWith:'_'},
    {separator:'---------------' },
    {name:'Link', openWith:'"', closeWith:'([![Title]!])":[![Link:!:http://]!]', placeHolder:'Your text to link here...' }
  ]
}
