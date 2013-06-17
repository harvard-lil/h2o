var popup_item_id = 0;
var popup_item_type = '';
var is_owner = false;
var permissions = {
  can_position_update: false,
  can_edit_notes: false
};
var last_data;
var access_results;
var panel_offset;
var panel_width;
var min_tick_width = 10;
var item_offset_top;
var right_offset;

var scife_fn_clicked = function() {
};

$.noConflict();

jQuery.extend({
  classType: function() {
    return jQuery('body').attr('id').replace(/^b/, '');
  },
  rootPath: function(){
    return '/';
  },
  mustache: function(template, data, partial, stream) {
    if(Mustache && template && data) {
      return Mustache.to_html(template, data, partial, stream);
    }
  },
  observeDefaultPrintListener: function() {
    if(jQuery.classType() != 'collages') {
      jQuery('#fixed_print').click(function(e) {
        var url = jQuery(this).attr('href');
        jQuery(this).attr('href', url + '#fontface=' + jQuery('#fontface a.active').data('value') + '-fontsize=' + jQuery('#fontsize a.active').data('value')); 
      });
    }
  },
  adjustTooltipPosition: function() {
    if(jQuery('#cancel-annotation').size()) {
      var el = jQuery('#' + jQuery('#cancel-annotation').data('id'));
      el.find('a.annotation_tip').tipsy("hide");
      el.find('a.annotation_tip').tipsy("show");
    }
  },
  setFixedLinkPosition: function() {
    if(jQuery('.singleitem').size()) {
      var top_offset = jQuery('.singleitem').offset().top;
      jQuery('.fixed_link').each(function(i, el) {
        jQuery(el).css('top', top_offset);
        top_offset += jQuery(el).height() + 2;
      });
      jQuery('#fixed_links').fadeIn();
      if(jQuery('.slide-out-div').size()) {
        jQuery.loadSlideOutTabBehavior(top_offset);
      }
    }
  },
  observeQuickCollage: function() {
    jQuery('#quick_collage').live('click', function(e) {
      e.preventDefault();
      var href = jQuery(this).attr('href');
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
          jQuery.hideGlobalSpinnerNode();
          jQuery('#quick_collage_node').remove();
          var quickCollageDialog = jQuery('<div id="quick_collage_node"></div>');
          jQuery(quickCollageDialog).html(html);
          jQuery(quickCollageDialog).find('.barcode_outer,.read-action,.link-add,.bookmark-action,.edit-external,.icon-delete').remove();
          jQuery(quickCollageDialog).dialog({
            title: 'Create a Collage',
            modal: true,
            width: '700',
            height: 'auto'
          });
          jQuery.observeResultsHover('#quick_collage_node');
          jQuery('#quick_collage_node .sort select').selectbox({
            className: "jsb", replaceInvisible: true 
          }).change(function() {
            var url = '/quick_collage?ajax=1&sort=' + jQuery(this).val();
            if(jQuery('#quick_collage_keyword').val() != '') {
              url += '&keywords=' + jQuery('#quick_collage_keyword').val();
            }
            jQuery.listCollageResults(url);
          });
        }
      });
    });
    jQuery('#quick_collage_node #quick_collage_search').live('click', function(e) {
      e.preventDefault();
      var url = '/quick_collage?ajax=1&sort=' + jQuery('#quick_collage_node .sort select').val();
      if(jQuery('#quick_collage_keyword').val() != '') {
        url += '&keywords=' + jQuery('#quick_collage_keyword').val();
      }
      jQuery.listCollageResults(url);
    });
    jQuery('#collage_pagination a').live('click', function(e) {
      e.preventDefault();
      jQuery.listCollageResults(jQuery(this).attr('href'));
    });
  },
  listCollageResults: function(href) {
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
        jQuery.hideGlobalSpinnerNode();
        jQuery('#quick_collage_node #results_set').hide().html(html);
        jQuery('#quick_collage_node #results_set').find('.barcode_outer,.read-action,.link-add,.bookmark-action,.edit-external,.icon-delete').remove();
        jQuery('#quick_collage_node #results_set').show();
        jQuery('#collage_pagination').html(jQuery('#quick_collage_node #new_pagination').html());
        jQuery('#new_pagination').remove();
        jQuery.observeResultsHover('#quick_collage_node');
      }
    });
  },
  resetFontSizeOptions: function() {
    var selected_font = jQuery('#fontface a.active').data('value');
    jQuery('#fontsize a').each(function(i, el) {
      jQuery(el).css({ 'font-family' : font_map[selected_font], 'font-size': base_font_sizes[selected_font][jQuery(el).data('value')] + 'px' });
    });
  },
  observeFontChange: function() {
    jQuery('#fontface a').each(function(i, el) {
      jQuery(el).css({ 'font-family': font_map[jQuery(el).data('value')], 'font-size' : base_font_sizes[jQuery(el).data('value')].small + 'px' });
    });
    jQuery.resetFontSizeOptions();
    jQuery('#fixed_font').click(function(e) {
      e.preventDefault();
      if(jQuery(this).hasClass('active')) {
        jQuery('#font-popup').hide();
        jQuery(this).removeClass('active');
      } else {
        jQuery(this).addClass('active');
        jQuery('#font-popup').css('top', jQuery(this).position().top).show();
      }
    });
    jQuery('#fontsize a:not(.active)').live('click', function(e) {
      e.preventDefault();
      jQuery('#fontsize a.active').removeClass('active');
      jQuery(this).addClass('active');
      jQuery.setFont();
    });
    jQuery('#fontface a:not(.active)').live('click', function(e) {
      e.preventDefault();
      jQuery('#fontface a.active').removeClass('active');
      jQuery(this).addClass('active');
      jQuery.setFont();
      jQuery.resetFontSizeOptions();
    });
    //var val = jQuery.cookie('font_size');
    //jQuery.cookie('font_size', element.val(), { path: "/" });
  },
  setPlaylistFontHierarchy: function(base_font_size) {
    jQuery.rule('.playlist a.title { font-size: ' + base_font_size*1.2 + 'px; }').appendTo('style');
    jQuery.rule('.playlist .playlist a.title { font-size: ' + base_font_size*1.1 + 'px; }').appendTo('style');
    jQuery.rule('.playlist .playlist .playlist a.title { font-size: ' + base_font_size*1.0 + 'px; }').appendTo('style');
    jQuery.rule('.playlist .playlist .playlist .playlist a.title { font-size: ' + base_font_size*0.9 + 'px; }').appendTo('style');
    jQuery.rule('.playlist .playlist .playlist .playlist .playlist a.title { font-size: ' + base_font_size*0.8 + 'px; }').appendTo('style');
  },
  setFont: function() {
    jQuery('.btn-a-active').click();
    var font_size = jQuery('#fontsize a.active').data('value');
    var font_face = jQuery('#fontface a.active').data('value');
    var base_font_size = base_font_sizes[font_face][font_size];
    if(font_face == 'verdana') {
      jQuery.rule("body .main_wrapper .singleitem article *, body .main_wrapper .singleitem div.playlists *, .singleitem article tt { font-family: Verdana, Arial, Helvetica, Sans-serif; font-size: " + base_font_size + 'px; }').appendTo('style');
    } else {
      jQuery.rule("body .main_wrapper .singleitem article *, body .main_wrapper .singleitem div.playlists *, .singleitem article tt { font-family: '" + font_map[font_face] + "'; font-size: " + base_font_size + 'px; }').appendTo('style');
    }
    jQuery.rule('.main_wrapper .singleitem *.scale1-5 { font-size: ' + base_font_size*1.5 + 'px; }').appendTo('style');
    jQuery.rule('.main_wrapper .singleitem *.scale1-4 { font-size: ' + base_font_size*1.4 + 'px; }').appendTo('style');
    jQuery.rule('.main_wrapper .singleitem *.scale1-3 { font-size: ' + base_font_size*1.3 + 'px; }').appendTo('style');
    jQuery.rule('.main_wrapper .singleitem *.scale1-1 { font-size: ' + base_font_size*1.1 + 'px; }').appendTo('style');
    jQuery.rule('.main_wrapper .singleitem *.scale0-9 { font-size: ' + base_font_size*0.9 + 'px; }').appendTo('style');
    jQuery.rule('.main_wrapper .singleitem *.scale0-8 { font-size: ' + base_font_size*0.8 + 'px; }').appendTo('style');
    jQuery.setPlaylistFontHierarchy(base_font_size);
    jQuery.adjustTooltipPosition();
  },
  observeResultsHover: function(region) {
    jQuery(region + ' #results .listitem').hoverIntent(function() {
      jQuery(this).addClass('hover');
      jQuery(this).find('.icon').addClass('hover');
    }, function() {
      jQuery(this).removeClass('hover');
      jQuery(this).find('.icon').removeClass('hover');
    });
  },
  initializeTooltips: function() {
    jQuery('.tooltip').tipsy({ gravity: 's', live: true, opacity: 1.0 });
    jQuery('.left-tooltip').tipsy({ gravity: 'e', live: true, opacity: 1.0 });
    jQuery('.nav-tooltip').tipsy({ gravity: 'n', live: true, opacity: 1.0 });
  },
  observeHomePageToggle: function() {
    jQuery('#featured_playlists .item, #featured_users .item').hoverIntent(function() {
      jQuery(this).find('.additional_details').slideDown(500);
    }, function() {
      jQuery(this).find('.additional_details').slideUp(200);
    });
  },
  observeTabDisplay: function() {
    jQuery(' .link-add a, a.link-add').live('click', function() {
      var element = jQuery(this);
      var current_id = element.data('item_id');
      if(jQuery('.singleitem').size()) {
        element.parentsUntil('.listitem').last().parent().addClass('adding-item');
      }
      jQuery('.with_popup').removeClass('with_popup');
      if(popup_item_id != 0 && current_id == popup_item_id) {
        jQuery('.add-popup').hide();
        popup_item_id = 0;
      } else {
        popup_item_id = current_id;
        popup_item_type = element.data('type');
        var addItemNode = jQuery(jQuery.mustache(add_popup_template, { "playlists": user_playlists }));
        jQuery(addItemNode).dialog({
          title: 'Add item to...',
          modal: true,
          width: 'auto',
          height: 'auto',
        }).dialog('open');
        if(jQuery('.singleitem').size() || jQuery.classType() == 'base') {
          //jQuery('.add-popup').hide().css({ top: '50%', left: '50%' }).fadeIn(100);
        } else {
          /* var listitem_element = jQuery('#listitem_' + popup_item_type + popup_item_id);
          listitem_element.addClass('with_popup');
          var position = listitem_element.offset(); */
        }
      }

      return false;
    });
    jQuery('.new-playlist-item').live('click', function(e) {
      var itemName = popup_item_type.charAt(0).toUpperCase() + popup_item_type.slice(1);
      if(itemName == 'Default') {
        itemName = 'Link';
      }
      jQuery.addItemToPlaylistDialog(popup_item_type + 's', itemName, popup_item_id, jQuery('#playlist_id').val()); 
      e.preventDefault();
    });
  },
  observeCreatePopup: function() {
    jQuery('#create_all:not(.active)').live('click', function(e) {
      e.preventDefault();
      jQuery('#create_all_popup').show();
      jQuery(this).addClass('active');
    });
    jQuery('#create_all.active').live('click', function(e) {
      e.preventDefault();
      jQuery('#create_all_popup').hide();
      jQuery(this).removeClass('active');
    });
    jQuery('#create_all_popup a').hover(function(e) {
      jQuery(this).find('span').addClass('hover');
    }, function(e) {
      jQuery(this).find('span').removeClass('hover');
    });
  },
  observeLoadMorePagination: function() {
    jQuery('.load_more_pagination a').live('click', function(e) {
      e.preventDefault();
      var current = jQuery(this);
      jQuery.ajax({
        method: 'GET',
        url: current.attr('href'),
        beforeSend: function(){
           jQuery.showGlobalSpinnerNode();
        },
        dataType: 'html',
        success: function(html){
          jQuery.hideGlobalSpinnerNode();
          current.parent().parent().append(jQuery(html));
          current.parent().remove();
          jQuery.initializeBarcodes();
        }
      });
    });
  },
  initializeBarcodes: function() {
    jQuery('.barcode a').tipsy({ gravity: 's', trigger: 'manual', opacity: 1.0 });
    jQuery('.barcode a').mouseover(function() {
      jQuery(this).tipsy('show');
      jQuery('.tipsy').addClass(jQuery(this).attr('class'));
    }).mouseout(function() {
      jQuery(this).tipsy('hide');
    });
    jQuery.each(jQuery('.barcode:not(.adjusted)'), function(i, el) {
      var current = jQuery(el);
      current.addClass('adjusted');
      var barcode_width = current.width();
      if(current.data('karma')*3 > barcode_width) {
        current.find('.barcode_wrapper').css({ left: '0px', width: current.data('karma') * 3 + current.data('ticks') });
      } else {
        current.find('.barcode_wrapper').css({ padding: '0px' });
        current.find('.overflow').hide();
        if(jQuery('#playlist.singleitem').size() && current.parent().hasClass('additional_details')) {
          current.width(current.data('karma') * 3 + current.data('ticks') + 5);
        }
      }
    });
    jQuery('.barcode').animate({ opacity: 1.0 });

    //TODO: Clean this up a bit to be more precise
    jQuery('span.right_overflow:not(.inactive)').live('click', function() {
      var current = jQuery(this);
      var wrapper = current.siblings('.barcode_wrapper');
      var min_left_position = -1*(wrapper.width() + 27 - current.parent().width());
      var standard_shift = -1*(current.parent().width() - 27);
      var position = parseInt(jQuery(this).siblings('.barcode_wrapper').css('left').replace('px', ''));
      if(position + standard_shift < min_left_position) {
        wrapper.animate({ left: min_left_position });
        current.addClass('inactive');
      } else {
        wrapper.animate({ left: position + standard_shift });
      }
      current.siblings('.left_overflow').removeClass('inactive');
    });
    jQuery('span.left_overflow:not(.inactive)').live('click', function() {
      var current = jQuery(this);
      var wrapper = current.siblings('.barcode_wrapper');
      var standard_shift = -1*(current.parent().width() - 21);
      var position = parseInt(jQuery(this).siblings('.barcode_wrapper').css('left').replace('px', ''));
      if(position - standard_shift > 0) {
        wrapper.animate({ left: 0 });
        current.addClass('inactive');
      } else {
        wrapper.animate({ left: position - standard_shift });
      }
      current.siblings('.right_overflow').removeClass('inactive');
    });
  },
  resetRightPanelThreshold: function() {
    if(jQuery('#collapse_toggle').size()) {
      var threshold = jQuery('.right_panel:visible').offset().top + jQuery('.right_panel:visible').height();
      jQuery('#collapse_toggle').data('threshold', threshold);
    }
  },
  adjustEditItemPositioning: function() {
    if(jQuery(window).scrollTop() < item_offset_top) {
      jQuery('#edit_item').css({ position: "relative", right: "0px" });
    } else {
      jQuery('#edit_item').css({ position: "fixed", right: right_offset, top: "0px" });
    }
    return false;
  },
  checkForPanelAdjust: function() {
    if(jQuery('body').hasClass('adjusting_now')) {
      return false;
    }
    if(jQuery('#edit_toggle').hasClass('edit_mode')) {
      jQuery.adjustEditItemPositioning();
      return false;
    }
    if(jQuery('#collapse_toggle').data('threshold') < jQuery(window).scrollTop()) {
      if(jQuery('.right_panel:visible').size() && jQuery.classType() == 'playlists') {
        jQuery('body').addClass('adjusting_now');
        jQuery('#collapse_toggle').addClass('special_hide');
        var scroll_position = jQuery(window).scrollTop();
        jQuery('.right_panel:visible').addClass('visible_before_hide').fadeOut(200, function() {
          jQuery('.singleitem').animate({ width: "100%" }, 100, function() {
            jQuery.adjustTooltipPosition();
            jQuery(window).scrollTop(scroll_position);
            jQuery('body').removeClass('adjusting_now');
          });
        });
      } else if(!jQuery('#collapse_toggle').hasClass('special_hide')) {
        jQuery('#collapse_toggle').addClass('hide_via_scroll');
        jQuery.adjustTooltipPosition();
      }
    } else if(jQuery('#collapse_toggle.special_hide').size() && jQuery(window).scrollTop() == 0) {
      jQuery('#collapse_toggle').removeClass('special_hide');
      jQuery('.singleitem').animate({ width: "747px" }, 100, 'swing', function() {
        jQuery('.right_panel.visible_before_hide').removeClass('visible_before_hide').fadeIn(200);
        jQuery.adjustTooltipPosition();
      });
    } else if(jQuery('#collapse_toggle.hide_via_scroll').size() && jQuery('#collapse_toggle').data('threshold') > jQuery(window).scrollTop()) {
      jQuery('#collapse_toggle').removeClass('hide_via_scroll');
      jQuery.adjustTooltipPosition();
    }
  },
  initializeRightPanelScroll: function() {
    if(jQuery('.right_panel').size()) {
      item_offset_top = jQuery('.singleitem').offset().top;
      right_offset = (jQuery('body').width() - jQuery('.main_wrapper').width()) / 2
      jQuery(window).scroll(function() {
        jQuery.checkForPanelAdjust();
      });
    }
  },
  observeViewerToggle: function() {
    jQuery('#collapse_toggle').click(function(e) {
      e.preventDefault();
      var el = jQuery(this);
      if(el.hasClass('expanded')) {
        el.removeClass('expanded');
        if(jQuery('#edit_toggle').size() && jQuery('#edit_toggle').hasClass('edit_mode')) {
          jQuery('.singleitem').animate({ width: "747px" }, 100, 'swing', function() {
            jQuery('#edit_item').fadeIn(200);
          });
        } else {
          jQuery('.singleitem').animate({ width: "747px" }, 100, 'swing', function() {
            jQuery('#stats').fadeIn(200);
          });
        }
      } else {
        el.addClass('expanded');
        if(jQuery('#edit_toggle').size() && jQuery('#edit_toggle').hasClass('edit_mode')) {
          jQuery('#edit_item').fadeOut(200, function() {
            jQuery('.singleitem').animate({ width: "100%" }, 100);
          });
        } else {
          jQuery('#stats').fadeOut(200, function() {
            jQuery('.singleitem').animate({ width: "100%" }, 100);
          });
        }
      }
    });
    jQuery('.right_panel_close').click(function(e) {
      e.preventDefault();
      jQuery('#collapse_toggle').click(); 
    }).hover(function() {
      jQuery('.right_panel').css('opacity', 0.5);
    }, function() {
      jQuery('.right_panel').css('opacity', 1.0);
    });
  },
  loadSlideOutTabBehavior: function(top_offset) {
    jQuery('.slide-out-div').tabSlideOut({
      tabHandle: '.handle',                     //class of the element that will become your tab
      pathToTabImage: '/images/report_error.png', //path to the image for the tab //Optionally can be set using css
      imageHeight: '135px',                     //height of tab image           //Optionally can be set using css
      imageWidth: '28px',                       //width of tab image            //Optionally can be set using css
      tabLocation: 'right',                      //side of screen where tab lives, top, right, bottom, or left
      speed: 500,                               //speed of animation
      action: 'click',                          //options: 'click' or 'hover', action to trigger animation
      topPos: top_offset + 'px',                          //position from the top/ use if tabLocation is left or right
      leftPos: '20px',                          //position from left/ use if tabLocation is bottom or top
      fixedPosition: true                      //options: true makes it stick(fixed position) on scroll
      //TODO: on open hide errors
    });
    jQuery('#defect_submit').click(function(e) {
      e.preventDefault();
      jQuery('#defect-form').ajaxSubmit({
        dataType: "JSON",
        beforeSend: function(){
          jQuery.showGlobalSpinnerNode();
          jQuery('#user-feedback-success, #user-feedback-error').hide().html('');
        },
        success: function(response){
          jQuery.hideGlobalSpinnerNode();
          jQuery('.slide-out-div').css('height', jQuery('.slide-out-div').height() + 30);
          if(response.error) {
            jQuery('#user-feedback-error').show().html(response.message);
          } else {
            jQuery.hideGlobalSpinnerNode();
            jQuery('#user-feedback-success').show().html('Thanks for your feedback. Panel will close shortly.');
            jQuery('#defect_description').val(' ');
            setTimeout(function() {
              jQuery('.handle').click();
              setTimeout(function() {
                jQuery('#user-feedback-success, #user-feedback-error').hide().html('');
              }, 500);
            }, 2000);
          }
        },
        error: function(data){
          jQuery.hideGlobalSpinnerNode();
          jQuery('.slide-out-div').css('height', jQuery('.slide-out-div').height() + 30);
          jQuery('#user-feedback-error').show().html('Sorry. We could not process your error. Please try again.');
        }
      });
    });
  },
  hideVisiblePopups: function() {
    if(jQuery('.btn-a-active').length) {
      jQuery('.btn-a-active').click();
    }
    if(jQuery('li.btn .active').length) {
      jQuery('li.btn .active').click();
    }
    if(jQuery('#font-popup').is(':visible')) {
      jQuery('#fixed_font').click();
    }
    if(jQuery('#create_all_popup').is(':visible')) {
      jQuery('#create_all_popup').hide();
      jQuery('#create_all').removeClass('active');
    }
    if(jQuery('.add-popup').is(':visible')) {
      jQuery('.with_popup').removeClass('with_popup');
      jQuery('.add-popup').hide();
      popup_item_id = 0;
    }
    if(jQuery('.ui-dialog').is(':visible')) {
      jQuery('.ui-dialog .ui-dialog-content').dialog('close');
    }
  },
  loadPopupCloseListener: function() {
    jQuery('.close-popup').live('click', function(e) {
      e.preventDefault();
      jQuery('.with_popup').removeClass('with_popup');
      jQuery.hideVisiblePopups();
    });
  },
  loadEscapeListener: function() {
    jQuery(document).keyup(function(e) {
      if(e.keyCode == 27) {
        jQuery.hideVisiblePopups();
      }
    });
  },
  loadOuterClicks: function() {
    jQuery('html').click(function(event) {
      var dont_hide = jQuery('.add-popup,#login-popup,.text-popup,.layers-popup,#font-popup,.ui-dialog').has(event.target).length > 0 ? true : false;
      if(jQuery(event.target).hasClass('dont_hide')) {
        dont_hide = true;
      }
      //if(jQuery(event.target).hasClass('jsb-moreButton')) {
      //  dont_hide = true;
      //}
      if(!dont_hide) {
        jQuery.hideVisiblePopups();
      }
    });
  },
  loadGenericEditability: function() {
    if(jQuery('a#logged-in').size()) {
      jQuery('.requires_logged_in').animate({ opacity: 1.0 });
    }
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
        //Global methods
        access_results = results;
        if(results.logged_in) {
          var data = jQuery.parseJSON(results.logged_in);
          jQuery('#user_account').append(jQuery('<a>').html(data.user.login + ' Dashboard').attr('href', "/users/" + data.user.id));
          jQuery('#defect_user_id').val(data.user.id);
          jQuery('.requires_logged_in').animate({ opacity: 1.0 });
          jQuery('#header_login').remove();
          if(jQuery.classType() == 'base') {
            jQuery('#base_dashboard').attr('href', "/users/" + data.user.id);
            jQuery('#get_started').remove();
            user_bookmarks = jQuery.parseJSON(results.bookmarks);
            jQuery.each(user_bookmarks, function(i, j) {
              jQuery('#' + i + ' .bookmark-action').addClass('inactive').html('<span class="icon icon-favorite"></span>BOOKMARKED');
            });
          }
          user_playlists = jQuery.parseJSON(results.playlists) || new Array();
        } else {
          jQuery('.requires_logged_in').remove();
        }
        jQuery('.afterload').animate({ opacity: 1.0 });
        jQuery.hideGlobalSpinnerNode();

        if(jQuery.classType() == 'collages') {  //Collages only
          last_data = jQuery.parseJSON(results.readable_state);
          jQuery.loadState();
          if(results.can_edit_annotations) {
            jQuery.listenToRecordCollageState();
            jQuery('.requires_edit').animate({ opacity: 1.0 });
          } else {
            jQuery('.requires_edit').remove();
          }
          if(results.can_edit_description) {
            jQuery('.edit-action').animate({ opacity: 1.0 });
          } else {
            jQuery('.edit-action').remove();
          }
        } else if(jQuery.classType() == 'playlists') {  //Playlists only
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
        }
        jQuery.setFixedLinkPosition();
      }
    });
  },
  observeTabBehavior: function() {
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
  },
  observeLoginPanel: function() {
    jQuery('#header_login').live('click', function(e) {
      e.preventDefault();
      jQuery('#login-popup').dialog({
        title: '',
        modal: true,
        width: 700,
        height: 'auto'
      });
    });
  },
  observeCasesVersions: function() {
    jQuery('.case_versions').live('click', function(e) {
      e.preventDefault();
      jQuery('#versions' + jQuery(this).data('id')).toggle();
      jQuery(this).toggleClass('active');
    });
    jQuery('.hide_versions').live('click', function(e) {
      e.preventDefault();
      jQuery('#versions' + jQuery(this).data('id')).toggle();
      jQuery(this).parent().siblings('.versions_details').find('.case_versions').removeClass('active');
    });
  },
  addItemToPlaylistDialog: function(itemController, itemName, itemId, playlistId) {
    var url_string = jQuery.rootPathWithFQDN() + itemController + '/' + itemId;
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
        jQuery('#generic-node').remove();
        var addItemDialog = jQuery('<div id="generic-node"></div>');
        jQuery(addItemDialog).html(html);
        jQuery(addItemDialog).find('#playlist_item_submit,#playlist_item_cancel').remove();
        jQuery(addItemDialog).dialog({
          title: 'Add this ' + itemName + ' to Your Playlist',
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
  listResults: function(href) {
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
        jQuery.hideGlobalSpinnerNode();
        if(href.match('collage_links')) { //TODO: Find out a more elegant way to represent this logic
          jQuery('#link_edit .dynamic').html(html).show();    
        } else {
          jQuery.address.value(href);
          jQuery('#results_set').html(html);
          jQuery('.standard_pagination').html(jQuery('#new_pagination').html());
          jQuery('#new_pagination').remove();
          jQuery.initializeBarcodes();
          jQuery.observeResultsHover('');
        }
      }
    });
  },
  observeSort: function() {
    jQuery('.sort select').selectbox({
      className: "jsb", replaceInvisible: true 
    }).change(function() {
      var sort = jQuery(this).val();
      var url = document.location.pathname;
      if(document.location.search != '') {
        url += document.location.search + "&sort=" + sort;
      } else {
        url += "?sort=" + sort;
      }
      jQuery.listResults(url);
    });
  },
  observePagination: function(){
    jQuery('.standard_pagination a').live('click', function(e){
      e.preventDefault();
      jQuery.listResults(jQuery(this).attr('href'));
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
  rootPathWithFQDN: function(){
    return location.protocol + '//' + location.hostname + ((location.port == '' || location.port == 80 || location.port == 443) ? '' : ':' + location.port) + '/';
  },
  showGlobalSpinnerNode: function() {
    jQuery('#spinner').show();
    jQuery('body').css('cursor', 'progress');
  },
  hideGlobalSpinnerNode: function() {
    jQuery('#spinner').hide();
    jQuery('body').css('cursor', 'auto');
  },
  showMajorError: function(xhr) {
    //empty for now
  },
  getItemId: function(element) {
    return jQuery(".singleitem").data("itemid");
  },
  toggleVisibilitySelector: function() {
    if (jQuery('.privacy_toggle').attr("checked") == "checked"){
      jQuery('#terms_require').html("<p class='inline-hints'>Submitting this item will allow others to see, copy, and create derivative works from this item in accordance with H2O's <a href=\"/p/terms\" target=\"_blank\">Terms of Service</a>.</p>")
    } else {
      jQuery('#terms_require').html("<p class='inline-hints'>If this item is submitted as a non-public item, other users will not be able to see, copy, or create derivative works from it, unless you change the item's setting to \"Public.\" Note that making a previously \"public\" item non-public will not affect copies or derivatives made from that public version.</p>");
    }
  },

  /* 
  This is a generic UI function that applies to all elements with the "icon-delete" class.
  With this, a dialog box is generated that asks the user if they want to delete the item (Yes, No).
  When a user clicks "Yes", an ajax call is made to the link's href, which responds with JSON.
  The listed item is then removed from the UI.
  */
  observeDestroyControls: function(region){
    jQuery(region + ' .icon-delete').live('click', function(e){
      e.preventDefault();
      if(jQuery(this).parent().hasClass('delete-playlist-item')) {
        return;
      }
      var destroyUrl = jQuery(this).attr('href');
      var item_id = destroyUrl.match(/[0-9]+$/).toString();
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
              beforeSend: function() {
                jQuery.showGlobalSpinnerNode();
              },
              error: function(xhr){
                jQuery.hideGlobalSpinnerNode();
              },
              success: function(data){
                jQuery(".listitem" + item_id).animate({ opacity: 0.0, height: 0 }, 200, function() {
                  jQuery(".listitem" + item_id).remove();
                  if(jQuery('#playlist').size()) {
                    jQuery.update_positions(data.position_data);
                  }
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
  observeBookmarkControls: function() {
    if(jQuery('.singleitem').size()) {
      var key = 'listitem_' + jQuery.classType().replace(/s$/, '') + jQuery('.singleitem').data('itemid');
      if(user_bookmarks[key]) {
        jQuery('.bookmark-action').addClass('inactive').html('<span class="icon icon-favorite-large"></span>').attr('title', 'Bookmarked');
        jQuery('.bookmark-action .icon').css('opacity', 0.3);
      }
    } else {
      jQuery.each(user_bookmarks, function(i, j) {
        jQuery('#' + i + ' .bookmark-action').addClass('inactive').html('<span class="icon icon-favorite-large"></span>BOOKMARKED');
      });
    }

    jQuery('.bookmark-action:not(.inactive)').live('click', function(e){
      var item_url = jQuery.rootPathWithFQDN() + 'bookmark_item/';
      var el = jQuery(this);
      item_url += el.data('type') + '/' + el.data('itemid');
      if (el.hasClass('link-bookmark')) {
        jQuery('#listitem_' + el.data('type') + el.data('itemid')).addClass('with_popup');
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
          if(!data.already_bookmarked) {
            if(jQuery.classType() == 'base') {
              el.addClass('inactive').html('<span class="icon icon-favorite"></span>BOOKMARKED');
            } else if (el.hasClass('link-bookmark')) {
              el.addClass('inactive').html('<span class="icon icon-favorite-large"></span>BOOKMARKED');
              setTimeout(function() {
                jQuery('#listitem_' + el.data('type') + el.data('itemid')).removeClass('with_popup');
              }, 500);
            } else {
              el.addClass('inactive').html('<span class="icon icon-favorite-large"></span>').attr('title', 'Bookmarked');
              el.find('.icon').css('opacity', 0.3);
            }
          }
        },
        error: function(xhr, textStatus, errorThrown) {
          jQuery.hideGlobalSpinnerNode();
        }
      });
    });
  },
  /* Generic HTML form elements */
  observeGenericControls: function(region){
    jQuery(region + ' .remix-action,' + region + ' .edit-action,' + region + ' .new-action,' + region + '.push-action').live('click', function(e){
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
    jQuery('#generic-node').remove();
    var newItemNode = jQuery('<div id="generic-node"></div>').html(html);
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
        if(newItemNode.find('#manage_playlists').length) {
          jQuery('#manage_playlists #lookup_submit').click();
        }
        if(newItemNode.find('#manage_collages').length) {
          jQuery('#manage_collages #lookup_submit').click();
        }
        if(newItemNode.find('#terms_require').length) {
          if(newItemNode.find('.privacy_toggle').length){
            jQuery('.privacy_toggle').click(function(){
              jQuery.toggleVisibilitySelector();
            });
          }
        }
        jQuery.toggleVisibilitySelector();
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
    jQuery('#generic-node #error_block').html('').hide();
    var buttons = jQuery('#generic-node').parent().find('button');
    if(buttons.first().hasClass('inactive')) {
      return false;
    }
    buttons.addClass('inactive');
    jQuery('#generic-node').find('form').ajaxSubmit({
      dataType: "JSON",
      beforeSend: function() {
        jQuery.showGlobalSpinnerNode();
      },
      success: function(data) {
        if(data.error) {
          jQuery('#generic-node #error_block').html(data.message).show(); 
          jQuery.hideGlobalSpinnerNode();
          buttons.removeClass('inactive');
        } else {
          if(data.custom_block) {
            eval('jQuery.' + data.custom_block + '(data)');
          } else {
            setTimeout(function() {
              var redirect_to = jQuery.rootPath() + data.type + '/' + data.id;
              var use_new_tab = jQuery.cookie('use_new_tab');
              if(use_new_tab == 'true'){
                window.open(redirect_to, '_blank');
              }
              else{
                document.location.href = redirect_to;
              }
                
            }, 1000);
          }
        }
      },
      error: function(xhr) {
        jQuery.hideGlobalSpinnerNode();
      },
    });
  },
  push_playlist: function(data) {
    jQuery.hideGlobalSpinnerNode();
    jQuery('#generic-node').dialog('close');
    jQuery('.main_wrapper').prepend(jQuery('<p>').attr('id', 'notice').html("Playlist is being pushed.  May take several minutes to complete. You'll receive an email when the push is completed."));
    window.scrollTo(0, 0);
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

  jQuery('#search_button').live('click', function(e) {
    e.preventDefault();
    jQuery("#search form").attr("action", "/" + jQuery('select#search_all').val());
    jQuery('#search form').submit();
  });
  jQuery('select#search_all').selectbox({
    className: "jsb", replaceInvisible: true 
  });

  jQuery(".link-more,.link-less").click(function(e) {
    jQuery("#description_less,#description_more").toggle();
    e.preventDefault();
  });

  jQuery('.item_drag_handle').button({icons: {primary: 'ui-icon-arrowthick-2-n-s'}});

  jQuery('li.submit a').click(function() {
    jQuery('form.search').submit();
  });

  /* End TODO */

  if(document.location.hash.match('ajax_region=')) {
    var region = jQuery('#results_' + jQuery.address.parameter('ajax_region')).parent();
    region.find('.special_sort select').val(jQuery.address.parameter('sort'));
    var url = document.location.hash.replace(/^#/, '');
    jQuery.listResultsSpecial(url, jQuery.address.parameter('ajax_region'));
    jQuery('html, body').animate({
      scrollTop: region.offset().top
    }, 100);
  } else if(document.location.hash.match('sort=')) {
    jQuery('#results .sort select').val(jQuery.address.parameter('sort'));
    var url = document.location.hash.replace(/^#/, '');
    jQuery.listResults(url);
  }

  jQuery.loadGenericEditability();
  jQuery.initializeBarcodes();
  jQuery.observeDestroyControls('');
  jQuery.observeGenericControls('');
  jQuery.observeBookmarkControls();
  jQuery.observePagination(); 
  jQuery.observeSort();
  //jQuery.observeCasesCollage();
  jQuery.observeCasesVersions();
  jQuery.observeTabDisplay();
  jQuery.observeLoginPanel();
  jQuery.observeResultsHover('');
  jQuery.observeTabBehavior();
  jQuery.loadEscapeListener();
  jQuery.loadPopupCloseListener();
  jQuery.loadOuterClicks();
  jQuery.observeViewerToggle();
  jQuery.observeLoadMorePagination();
  jQuery.initializeTooltips();
  jQuery.observeCreatePopup();
  jQuery.observeHomePageToggle();
  jQuery.observeFontChange();
  jQuery.observeMetadataForm();
  jQuery.observeMetadataDisplay();
  jQuery.observeQuickCollage();
  jQuery.initializeRightPanelScroll();
  jQuery.resetRightPanelThreshold();
  jQuery.observeDefaultPrintListener();

  if(jQuery('body').hasClass('bbase_index')) {
    jQuery.loadEditability();
  }

  if(jQuery.classType() != 'collages' && jQuery.classType() != 'playlists') {
    jQuery.setFixedLinkPosition();
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
  previewParserPath:  '/base/preview_textile_content',
  previewAutoRefresh: true,
  onShiftEnter:    {keepDefault:false, replaceWith:'\n\n'},
  markupSet: [
    {name:'Bold', key:'B', closeWith:'*', openWith:'*'},
    {name:'Underline', key:'U', closeWith:'_', openWith:'_'},
    {separator:'---------------' },
    {name:'Link', openWith:'"', closeWith:'([![Title]!])":[![Link:!:http://]!]', placeHolder:'Your text to link here...' }
  ]
}

var add_popup_template = '\
<div class="popup add-popup">\
  <div class="select-wrapper"><select id="playlist_id">\
  {{#playlists}}\
  {{#playlist}}\
  <option value="{{id}}">{{name}}</option>\
  {{/playlist}}\
  {{/playlists}}\
  </select></div>\
  <div class="btn-wrapper"><a href="#" class="button new-playlist-item">SAVE</a></div></div>';
