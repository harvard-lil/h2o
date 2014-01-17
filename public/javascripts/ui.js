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
var user_playlists = new Array();
var scife_fn_clicked = function() {
};
var page_load = true;
var list_results_url = '';

$.extend({
  classType: function() {
    return $('body').attr('id').replace(/^b/, '');
  },
  rootPath: function(){
    return '/';
  },
  mustache: function(template, data, partial, stream) {
    if(Mustache && template && data) {
      return Mustache.to_html(template, data, partial, stream);
    }
  },
  setListLinkVisibility: function() {
    if($.cookie('user_id') == null) {
      $('.controls').remove();
    }
    // TODO: Lookup owned playlists & remove Push link if not owned
  },
  resetSort: function(sort_value, sort) {
    if(sort_value != sort.val()) {
      sort.find('option:selected').removeAttr('selected');
      var new_option = sort.find('option[value="' + sort_value + '"]');
      new_option.attr('selected', 'selected');
      sort.siblings('.jsb-currentItem').html(new_option.html());
    } 
  },
  observeDefaultDescriptionShow: function() {
    $(document).delegate('.show_default_description', 'click', function(e) {
      e.preventDefault();
      $(this).hide();
      $(this).next('.default_description').show();
    });
    $(document).delegate('.hide_default_description', 'click', function(e) {
      e.preventDefault();
      $(this).parent().hide();
      $(this).parent().prev('.show_default_description').show();
    });
  },
  adjustArticleHeaderSizes: function() {
    $('article h1').addClass('scale1-4');
    $('article h2').addClass('scale1-3');
    $('article h3').addClass('scale1-2');
    $('article h4').addClass('scale1-1');
  },
  observeDefaultPrintListener: function() {
    if($.classType() != 'collages') {
      $('#fixed_print,#quickbar_print').click(function(e) {
        var url = $(this).attr('href');
        $(this).attr('href', url + '#fontface=' + $('#fontface a.active').data('value') + '-fontsize=' + $('#fontsize a.active').data('value')); 
      });
    }
  },
  adjustTooltipPosition: function() {
    if($('#cancel-annotation').size()) {
      var el = $('#' + $('#cancel-annotation').data('id'));
      el.find('a.annotation_tip').tipsy("hide");
      el.find('a.annotation_tip').tipsy("show");
    }
  },
  setFixedLinkPosition: function() {
    if($('.singleitem').size()) {
      var top_offset = $('.singleitem').offset().top;
      $('.fixed_link').each(function(i, el) {
        $(el).css('top', top_offset);
        top_offset += $(el).height() + 2;
      });
      $('#fixed_links').fadeIn();
      if($('.slide-out-div').size() && page_load) {
        $.loadSlideOutTabBehavior(top_offset);
        page_load = false;
      }
    }
  },
  observeQuickCollage: function() {
    $('#quick_collage').on('click', function(e) {
      e.preventDefault();
      var href = $(this).attr('href');
      $.ajax({
        type: 'GET',
        dataType: 'html',
        url: href,
        beforeSend: function(){
          $.showGlobalSpinnerNode();
        },
        error: function(xhr){
          $.hideGlobalSpinnerNode();
        },
        success: function(html){
          $.hideGlobalSpinnerNode();
          $('#quick_collage_node').remove();
          var quickCollageDialog = $('<div id="quick_collage_node"></div>');
          $(quickCollageDialog).html(html);
          $(quickCollageDialog).find('.barcode_outer,.read-action,.link-add,.bookmark-action,.edit-external,.icon-delete').remove();
          $(quickCollageDialog).dialog({
            title: 'Create a Collage',
            modal: true,
            width: '700',
            height: 'auto'
          });
          $.observeResultsHover('#quick_collage_node');
          $('#quick_collage_node .sort select').selectbox({
            className: "jsb", replaceInvisible: true 
          }).change(function() {
            var url = '/quick_collage?ajax=1&sort=' + $(this).val();
            if($('#quick_collage_keyword').val() != '') {
              url += '&keywords=' + $('#quick_collage_keyword').val();
            }
            $.listCollageResults(url);
          });
        }
      });
    });
    $(document).delegate('#quick_collage_node #quick_collage_search', 'click', function(e) {
      e.preventDefault();
      var url = '/quick_collage?ajax=1&sort=' + $('#quick_collage_node .sort select').val();
      if($('#quick_collage_keyword').val() != '') {
        url += '&keywords=' + $('#quick_collage_keyword').val();
      }
      $.listCollageResults(url);
    });
    $(document).delegate('#collage_pagination a', 'click', function(e) {
      e.preventDefault();
      $.listCollageResults($(this).attr('href'));
    });
  },
  listCollageResults: function(href) {
    $.ajax({
      type: 'GET',
      dataType: 'html',
      url: href,
      beforeSend: function(){
           $.showGlobalSpinnerNode();
         },
         error: function(xhr){
           $.hideGlobalSpinnerNode();
      },
      success: function(html){
        $.hideGlobalSpinnerNode();
        $('#quick_collage_node #results_set').hide().html(html);
        $('#quick_collage_node #results_set').find('.barcode_outer,.read-action,.link-add,.bookmark-action,.edit-external,.icon-delete').remove();
        $('#quick_collage_node #results_set').show();
        $('#collage_pagination').html($('#quick_collage_node #new_pagination').html());
        $('#new_pagination').remove();
        $.observeResultsHover('#quick_collage_node');
      }
    });
  },
  resetFontSizeOptions: function() {
    var selected_font = $('#fontface a.active').data('value');
    $('#fontsize a').each(function(i, el) {
      $(el).css({ 'font-family' : font_map[selected_font], 'font-size': base_font_sizes[selected_font][$(el).data('value')] + 'px' });
    });
  },
  observeFontChange: function() {
    $('#fontface a').each(function(i, el) {
      $(el).css({ 'font-family': font_map[$(el).data('value')], 'font-size' : base_font_sizes[$(el).data('value')].small + 'px' });
    });
    $.resetFontSizeOptions();
    $('#fixed_font').click(function(e) {
      e.preventDefault();
      var flink = $(this);
      if(flink.hasClass('active')) {
        $('#font-popup').fadeOut(100);
        flink.removeClass('active');
      } else {
        flink.addClass('active');
        $('#font-popup').removeClass('quickbar').css({ top: flink.position().top, right: 28, left: '' }).fadeIn(100);
      }
    });
    $('#quickbar_font').click(function(e) {
      e.preventDefault();
      var qlink = $(this);
      if(qlink.hasClass('active')) {
        $('#font-popup').fadeOut(100);
        qlink.removeClass('active');
      } else {
        qlink.addClass('active');
        $('#font-popup').addClass('quickbar').css({ top: qlink.position().top + 20, right: 0, left: qlink.position().left - 185 }).fadeIn(100);
      }
    });
    $(document).delegate('#fontsize a:not(.active)', 'click', function(e) {
      e.preventDefault();
      $('#fontsize a.active').removeClass('active');
      $(this).addClass('active');
      $.setFont();
    });
    $(document).delegate('#fontface a:not(.active)', 'click', function(e) {
      e.preventDefault();
      $('#fontface a.active').removeClass('active');
      $(this).addClass('active');
      $.setFont();
      $.resetFontSizeOptions();
    });
    //var val = $.cookie('font_size');
    //$.cookie('font_size', element.val(), { path: "/" });
  },
  setPlaylistFontHierarchy: function(base_font_size) {
    $.rule('.playlist a.title { font-size: ' + base_font_size*1.2 + 'px; }').appendTo('style');
    $.rule('.playlist .playlist a.title { font-size: ' + base_font_size*1.1 + 'px; }').appendTo('style');
    $.rule('.playlist .playlist .playlist a.title { font-size: ' + base_font_size*1.0 + 'px; }').appendTo('style');
    $.rule('.playlist .playlist .playlist .playlist a.title { font-size: ' + base_font_size*0.9 + 'px; }').appendTo('style');
    $.rule('.playlist .playlist .playlist .playlist .playlist a.title { font-size: ' + base_font_size*0.8 + 'px; }').appendTo('style');
  },
  setFont: function() {
    $('.btn-a-active').click();
    var font_size = $('#fontsize a.active').data('value');
    var font_face = $('#fontface a.active').data('value');
    var base_font_size = base_font_sizes[font_face][font_size];
    if(font_face == 'verdana') {
      $.rule("body .main_wrapper .singleitem article *, body .main_wrapper .singleitem div.playlists *, .singleitem article tt, #bmedias #description p { font-family: Verdana, Arial, Helvetica, Sans-serif; font-size: " + base_font_size + 'px; }').appendTo('style');
    } else {
      $.rule("body .main_wrapper .singleitem article *, body .main_wrapper .singleitem div.playlists *, .singleitem article tt, #bmedias #description p { font-family: '" + font_map[font_face] + "'; font-size: " + base_font_size + 'px; }').appendTo('style');
    }
    $.rule('.main_wrapper .singleitem *.scale1-5 { font-size: ' + base_font_size*1.5 + 'px; }').appendTo('style');
    $.rule('.main_wrapper .singleitem *.scale1-4 { font-size: ' + base_font_size*1.4 + 'px; }').appendTo('style');
    $.rule('.main_wrapper .singleitem *.scale1-3 { font-size: ' + base_font_size*1.3 + 'px; }').appendTo('style');
    $.rule('.main_wrapper .singleitem *.scale1-2 { font-size: ' + base_font_size*1.1 + 'px; }').appendTo('style');
    $.rule('.main_wrapper .singleitem *.scale1-1 { font-size: ' + base_font_size*1.1 + 'px; }').appendTo('style');
    $.rule('.main_wrapper .singleitem *.scale0-9 { font-size: ' + base_font_size*0.9 + 'px; }').appendTo('style');
    $.rule('.main_wrapper .singleitem *.scale0-8 { font-size: ' + base_font_size*0.8 + 'px; }').appendTo('style');
    $.setPlaylistFontHierarchy(base_font_size);
    $.adjustTooltipPosition();
  },
  observeResultsHover: function(region) {
    $(region + ' #results .listitem').hoverIntent(function() {
      $(this).addClass('hover');
      $(this).find('.icon').addClass('hover');
    }, function() {
      $(this).removeClass('hover');
      $(this).find('.icon').removeClass('hover');
    });
  },
  initializeTooltips: function() {
    $('.tooltip').tipsy({ gravity: 's', live: true, opacity: 1.0 });
    $('.left-tooltip').tipsy({ gravity: 'e', live: true, opacity: 1.0 });
    $('.nav-tooltip').tipsy({ gravity: 'p', opacity: 1.0 });
    $('#quickbar_right a').tipsy({ gravity: 'n', opacity: 1.0 });
  },
  observeHomePageBehavior: function() {
    if($('body.bbase_index').size()) {
      $('#featured_playlists .item, #featured_users .item').hoverIntent(function() {
        $(this).find('.additional_details').slideDown(500);
      }, function() {
        $(this).find('.additional_details').slideUp(200);
      });
      $('#masonry_collection').masonry({
        itemSelector: '.panel',
        gutter: 20,
        columnWidth: 258
      });
    }
  },
  observeTabDisplay: function() {
    $(document).delegate('.ui-dialog-titlebar-close', 'click', function() {
      popup_item_id = 0;
    });
    $(document).delegate(' .link-add a, a.link-add', 'click', function() {
      var element = $(this);
      var current_id = element.data('item_id');
      if($('.singleitem').size()) {
        element.parentsUntil('.listitem').last().parent().addClass('adding-item');
      }
      if(popup_item_id != 0 && current_id == popup_item_id) {
        $('.add-popup').hide();
        popup_item_id = 0;
      } else {
        popup_item_id = current_id;
        popup_item_type = element.data('type');
        var addItemNode = $($.mustache(add_popup_template, { "playlists": user_playlists }));
        $(addItemNode).dialog({
          title: 'Add item to...',
          modal: true,
          width: 'auto',
          height: 'auto',
        }).dialog('open');
      }

      return false;
    });
    $(document).delegate('.new-playlist-item', 'click', function(e) {
      $.addItemToPlaylistDialog(popup_item_type, popup_item_id, $('#playlist_id').val()); 
      e.preventDefault();
    });
  },
  observeCreatePopup: function() {
    $(document).delegate('#create_all', 'click', function(e) {
      e.preventDefault();
      $('#create_all_popup').css({ left: $('#create_all').position().left - 95, top: $('#create_all').offset().top - 8 });
      $('#create_all_popup').toggle();
      $(this).toggleClass('active');
    });
    $('#create_all_popup a').hover(function(e) {
      $(this).find('span').addClass('hover');
    }, function(e) {
      $(this).find('span').removeClass('hover');
    });
  },
  observeLoadMorePagination: function() {
    $(document).delegate('.load_more_pagination a', 'click', function(e) {
      e.preventDefault();
      var current = $(this);
      $.ajax({
        method: 'GET',
        url: current.attr('href'),
        beforeSend: function(){
           $.showGlobalSpinnerNode();
        },
        dataType: 'html',
        success: function(html){
          $.hideGlobalSpinnerNode();
          current.parent().parent().append($(html));
          current.parent().remove();
          $.initializeBarcodes();
        }
      });
    });
  },
  initializeBarcodes: function() {
    $('.barcode a').tipsy({ gravity: 's', trigger: 'manual', opacity: 1.0, offset: 10 });
    $('.barcode a').mouseover(function() {
      $(this).tipsy('show');
      $('.tipsy').addClass($(this).attr('class') + ' tipsy-barcode');
    }).mouseout(function() {
      $(this).tipsy('hide');
    });
    $.each($('.barcode:not(.adjusted)'), function(i, el) {
      var current = $(el);
      current.addClass('adjusted');
      var barcode_width = current.width();
      if(current.data('karma')*3 > barcode_width) {
        current.find('.barcode_wrapper').css({ left: '0px', width: current.data('karma') * 3 + current.data('ticks') });
      } else {
        current.find('.barcode_wrapper').css({ padding: '0px' });
        current.find('.overflow').hide();
        if($('#playlist.singleitem').size() && current.parent().hasClass('additional_details')) {
          current.width(current.data('karma') * 3 + current.data('ticks') + 5);
        }
      }
    });
    $('.barcode').animate({ opacity: 1.0 });

    //TODO: Clean this up a bit to be more precise
    $(document).delegate('span.right_overflow:not(.inactive)', 'click', function() {
      var current = $(this);
      var wrapper = current.siblings('.barcode_wrapper');
      var min_left_position = -1*(wrapper.width() + 27 - current.parent().width());
      var standard_shift = -1*(current.parent().width() - 27);
      var position = parseInt($(this).siblings('.barcode_wrapper').css('left').replace('px', ''));
      if(position + standard_shift < min_left_position) {
        wrapper.animate({ left: min_left_position });
        current.addClass('inactive');
      } else {
        wrapper.animate({ left: position + standard_shift });
      }
      current.siblings('.left_overflow').removeClass('inactive');
    });
    $(document).delegate('span.left_overflow:not(.inactive)', 'click', function() {
      var current = $(this);
      var wrapper = current.siblings('.barcode_wrapper');
      var standard_shift = -1*(current.parent().width() - 21);
      var position = parseInt($(this).siblings('.barcode_wrapper').css('left').replace('px', ''));
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
    if($('#collapse_toggle').size()) {
      var threshold = $('.right_panel:visible').offset().top + $('.right_panel:visible').height();
      $('#collapse_toggle').data('threshold', threshold);
    }
  },
  adjustEditItemPositioning: function() {
    if($(window).scrollTop() < item_offset_top) {
      $('#edit_item').removeClass('fixed_position').css({ right: '0px', top: '0px' });
    } else {
      $('#edit_item').addClass('fixed_position').css({ top: $('#quickbar').height() + 10, right: right_offset });
    }
    return false;
  },
  adjustQuickbarDisplay: function() {
    if($('#quickbar').is(':visible') && $(window).scrollTop() < item_offset_top + 15) {
      $('#font-popup,.text-layers-popup').fadeOut(100);
      $('#quickbar').fadeOut(200);
      $('#quickbar_font,#quickbar_tools').removeClass('active');
      $('#text-layer-tools').removeClass('btn-a-active');
      $('#fixed_font,#fixed_print,#edit_toggle').fadeIn(200);
    } else if(!$('#quickbar').is(':visible') && $(window).scrollTop() > item_offset_top + 15) {
      $('#font-popup,.text-layers-popup').fadeOut(100);
      $('#quickbar').fadeIn(200);
      $('#fixed_font').removeClass('active');
      $('#fixed_font,#fixed_print,#edit_toggle').fadeOut(200);
      $('#text-layer-tools').removeClass('btn-a-active');
    }
  },
  checkForPanelAdjust: function() {
    if($('body').hasClass('adjusting_now')) {
      return false;
    }
    $.adjustQuickbarDisplay();
    if($('#edit_toggle').hasClass('edit_mode')) {
      $.adjustEditItemPositioning();
      return false;
    }
    if($('#collapse_toggle').data('threshold') < $(window).scrollTop()) {
      if($('.right_panel:visible').size() && $.classType() == 'playlists') {
        $('body').addClass('adjusting_now');
        $('#collapse_toggle').addClass('special_hide');
        var scroll_position = $(window).scrollTop();
        $('.right_panel:visible').addClass('visible_before_hide').hide();
        $('.singleitem').addClass('expanded_singleitem');
        $.adjustTooltipPosition();
        $(window).scrollTop(scroll_position);
        $('body').removeClass('adjusting_now');
      } else if(!$('#collapse_toggle').hasClass('special_hide')) {
        $('#collapse_toggle').addClass('hide_via_scroll');
        $.adjustTooltipPosition();
      }
    } else if($('#collapse_toggle.special_hide').size() && $(window).scrollTop() == 0) {
      $('#collapse_toggle').removeClass('special_hide');
      $('.singleitem').removeClass('expanded_singleitem');
      $('.right_panel.visible_before_hide').removeClass('visible_before_hide').show();
      $.adjustTooltipPosition();
    } else if($('#collapse_toggle.hide_via_scroll').size() && $('#collapse_toggle').data('threshold') > $(window).scrollTop()) {
      $('#collapse_toggle').removeClass('hide_via_scroll');
      $.adjustTooltipPosition();
    } 
  },
  initializeRightPanelScroll: function() {
    if($('.right_panel').size()) {
      item_offset_top = $('.singleitem').offset().top - 15;
      right_offset = ($('body').width() - $('.main_wrapper').width()) / 2
      $(window).scroll(function() {
        $.checkForPanelAdjust();
      });
    }
  },
  observeViewerToggle: function() {
    $('#collapse_toggle').click(function(e) {
      e.preventDefault();
      var el = $(this);
      if(el.hasClass('expanded')) {
        el.removeClass('expanded');
        $('.singleitem').removeClass('expanded_singleitem');
        if($('#edit_toggle').size() && $('#edit_toggle').hasClass('edit_mode')) {
          $('#edit_item').show();
        } else {
          $('#stats').show();
        }
      } else {
        el.addClass('expanded');
        if($('#edit_toggle').size() && $('#edit_toggle').hasClass('edit_mode')) {
          $('#edit_item').hide();
        } else {
          $('#stats').hide();
        }
        $('.singleitem').addClass('expanded_singleitem');
      }
    });
    $('.right_panel_close').click(function(e) {
      e.preventDefault();
      $('#collapse_toggle').click(); 
    }).hover(function() {
      $('.right_panel').css('opacity', 0.5);
    }, function() {
      $('.right_panel').css('opacity', 1.0);
    });
  },
  loadSlideOutTabBehavior: function(top_offset) {
    $('.slide-out-div').tabSlideOut({
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
    $('#defect_submit').click(function(e) {
      e.preventDefault();
      $('#defect-form').ajaxSubmit({
        dataType: "JSON",
        beforeSend: function(){
          $.showGlobalSpinnerNode();
          $('#user-feedback-success, #user-feedback-error').hide().html('');
        },
        success: function(response){
          $.hideGlobalSpinnerNode();
          $('.slide-out-div').css('height', $('.slide-out-div').height() + 30);
          if(response.error) {
            $('#user-feedback-error').show().html(response.message);
          } else {
            $.hideGlobalSpinnerNode();
            $('#user-feedback-success').show().html('Thanks for your feedback. Panel will close shortly.');
            $('#defect_description').val(' ');
            setTimeout(function() {
              $('.handle').click();
              setTimeout(function() {
                $('#user-feedback-success, #user-feedback-error').hide().html('');
              }, 500);
            }, 2000);
          }
        },
        error: function(data){
          $.hideGlobalSpinnerNode();
          $('.slide-out-div').css('height', $('.slide-out-div').height() + 30);
          $('#user-feedback-error').show().html('Sorry. We could not process your error. Please try again.');
        }
      });
    });
  },
  hideVisiblePopups: function() {
    if($('.btn-a-active').length) {
      $('.btn-a-active').click();
    }
    if($('li.btn .active').length) {
      $('li.btn .active').click();
    }
    if($('.text-layers-popup').is(':visible') && $('#quickbar').is(':visible')) {
      $('#quickbar_tools').click();
    } 
    if($('#font-popup').is(':visible')) {
      if($('#font-popup').hasClass('quickbar')) {
        $('#quickbar_font').click();
      } else {
        $('#fixed_font').click();
      }
    }
    if($('#create_all_popup').is(':visible')) {
      $('#create_all_popup').hide();
      $('#create_all').removeClass('active');
    }
    if($('.add-popup').is(':visible')) {
      $('.add-popup').hide();
      popup_item_id = 0;
    }
    if($('.ui-dialog').is(':visible')) {
      $('.ui-dialog .ui-dialog-content').dialog('close');
    }
    return true;
  },
  loadEscapeListener: function() {
    $(document).keyup(function(e) {
      if(e.keyCode == 27) {
        $.hideVisiblePopups();
      }
    });
  },
  loadOuterClicks: function() {
    $('html').click(function(event) {
      if($('#nonsupported_browser').size()) {
        return;
      }
      var dont_hide = $('.add-popup,#login-popup,.text-layers-popup,#font-popup,.ui-dialog,#create_nav,#quickbar_right').has(event.target).length > 0 ? true : false;
      if($(event.target).hasClass('dont_hide')) {
        dont_hide = true;
      }
      if(!dont_hide) {
        $.hideVisiblePopups();
      }
    });
  },
  loadEditability: function() {
    if($.cookie('user_id') == null) {
      //lack of cookies indicate user not logged in. Skipping
      $('.requires_edit, .requires_logged_in, .requires_remove, .requires_non_anonymous').remove();
      $('.afterload').css('opacity', 1.0);
      $.setFixedLinkPosition();
      if($('body').hasClass('bplaylists_show')) {
        $.playlist_mark_private('', false);
      }
      if($('body').hasClass('bcollages_show')) {
        $.initiate_annotator(false);
      }
      return;
    } else {
      if(eval($.cookie('anonymous_user'))) {
        $('.requires_non_anonymous').remove(); 
      } else {
        $('.requires_non_anonymous').animate({ opacity: 1.0 });
      }
      $('#user_account').append($('<a>').html($.cookie('display_name').replace(/\+/g, ' ') + ' Dashboard').attr('href', "/users/" + $.cookie('user_id')));
      $('#defect_user_id').val($.cookie('user_id'));
      $('.requires_logged_in').animate({ opacity: 1.0 });
      $('#header_login').remove();
      if($.classType() == 'base') {
        $('#base_dashboard').attr('href', "/users/" + $.cookie('user_id'));
        $('#get_started').remove();
      }
    }

    if(editability_path == '') {
      $('.afterload').animate({ opacity: 1.0 });
      return;
    }

    $.ajax({
      type: 'GET',
      cache: false,
      url: editability_path,
      dataType: "JSON",
      beforeSend: function(){
        $.showGlobalSpinnerNode();
      },
      error: function(xhr){
        $.hideGlobalSpinnerNode();
        $('.requires_edit').remove();
        $('.requires_logged_in').remove();
        $('.afterload').animate({ opacity: 1.0 });
        $.hideGlobalSpinnerNode();
      },
      success: function(results){
        access_results = results;
        $('.afterload').animate({ opacity: 1.0 });
        $.hideGlobalSpinnerNode();

        if(results.custom_block) {
          eval('$.' + results.custom_block + '(results)');
        }
        $.setFixedLinkPosition();
      }
    });
  },
  observeTabBehavior: function() {
    $('.tabs a').click(function(e) {
      var region = $(this).data('region');
      $('.add-popup').hide();
      popup_item_id = 0;
      popup_item_type = '';
      $('.tabs a').removeClass("active");
      $('.songs > ul').hide();
      $('.pagination > div, .sort > div').hide();
      $('#' + region +
        ',.' + region + '_pagination' +
        ',#' + region + '_sort').show();
      $(this).addClass("active");
      e.preventDefault();
    });
  },
  observeLoginPanel: function() {
    $(document).delegate('#header_login', 'click', function(e) {
      e.preventDefault();
      $('#login-popup').dialog({
        title: '',
        modal: true,
        width: 700,
        height: 'auto'
      });
    });
  },
  observeCasesVersions: function() {
    $(document).delegate('.case_versions', 'click', function(e) {
      e.preventDefault();
      $('#versions' + $(this).data('id')).toggle();
      $(this).toggleClass('active');
    });
    $(document).delegate('.hide_versions', 'click', function(e) {
      e.preventDefault();
      $('#versions' + $(this).data('id')).toggle();
      $(this).parent().siblings('.versions_details').find('.case_versions').removeClass('active');
    });
  },
  addItemToPlaylistDialog: function(klass, item_id, playlist_id) {
    var url = $.rootPathWithFQDN() + klass + 's/' + item_id;
    $.ajax({
      method: 'GET',
      cache: false,
      dataType: "html",
      url: $.rootPath() + 'playlist_items/new',
      beforeSend: function(){
           $.showGlobalSpinnerNode();
      },
      data: {
        klass: klass,
        id: item_id,
        url: url,
        playlist_id: playlist_id
      },
      success: function(html){
        $.hideGlobalSpinnerNode();
        $('#dialog-item-chooser').dialog('close');
        $('#generic-node').remove();
        var addItemDialog = $('<div id="generic-node"></div>');
        $(addItemDialog).html(html);
        $(addItemDialog).find('#playlist_item_submit,#playlist_item_cancel').remove();
        $(addItemDialog).dialog({
          title: 'Add to your playlist',
          modal: true,
          width: 'auto',
          height: 'auto',
          buttons: {
            Save: function(){
              $.submitGenericNode();
            },
            Close: function(){
              $(addItemDialog).dialog('close');
            }
          }
        });
      }
    });
  },
  observeMarkItUpFields: function() {
    $('.textile_description').observeField(5,function(){
        $.ajax({
        cache: false,
        type: 'POST',
        url: $.rootPath() + 'collages/description_preview',
        data: {
            preview: $('.textile_description').val()
        },
           success: function(html){
            $('.textile_preview').html(html);
        }
        });
    });
  },
  listResults: function(href, store_address) {
    list_results_url = href;

    $.ajax({
      type: 'GET',
      dataType: 'html',
      url: href,
      beforeSend: function(){
           $.showGlobalSpinnerNode();
         },
         error: function(xhr){
           $.hideGlobalSpinnerNode();
      },
      success: function(html){
        $.hideGlobalSpinnerNode();
        if(href.match('collage_links')) {
          if($('.singleitem').data('annotator_version') == '1') {
            $('#link_edit .dynamic').html(html).show();    
          } else {
            $('#collage_links').html(html).show();    
          }
        } else {
          if(store_address) {
            $.address.value(href);
            $.cookie('return_to', document.location.pathname + '#' + href, { path: '/' });
          }
          $('#results_set').html(html);
          $('.standard_pagination').html($('#new_pagination').html());
          $('#new_pagination').remove();
          $.initializeBarcodes();
          $.observeResultsHover('');
          if($('.busers_show').length) {
            $.renderDeleteFunctionality();
          }
        }
      }
    });
  },
  observeSort: function() {
    $('.sort select').selectbox({
      className: "jsb", replaceInvisible: true 
    }).change(function() {
      var sort = $(this).val();
      var url = document.location.pathname;
      if(document.location.search != '') {
        url += document.location.search + "&sort=" + sort;
      } else {
        url += "?sort=" + sort;
      }
      if($('#user_keywords').length) {
        url += '&keywords=' + $('#user_keywords').val();
      }
      $.listResults(url, true);
    });
  },
  observePagination: function(){
    $(document).delegate('.standard_pagination a,#collage_links .pagination a,#link_edit .pagination a', 'click', function(e){
      e.preventDefault();
      $.listResults($(this).attr('href'), true);
    });
  },

  observeMetadataForm: function(){
    $('.datepicker').datepicker({
      changeMonth: true,
      changeYear: true,
      yearRange: 'c-300:c',
      dateFormat: 'yy-mm-dd'
    });
    $('form .metadata ol').toggle();
    $('form .metadata legend').bind({
      click: function(e){
        e.preventDefault();
        $('form .metadata ol').toggle();
      },
      mouseover: function(){
        $(this).css({cursor: 'hand'});
      },
      mouseout: function(){
        $(this).css({cursor: 'pointer'});
      }
    });
  },

  observeMetadataDisplay: function(){
    $('.metadatum-display').click(function(e){
      e.preventDefault();
      $(this).find('ul').toggle();
    });
  },

  observeTagAutofill: function(className,controllerName){
    if($(className).length > 0){
     $(document).delegate(className, 'click',function(){
     $(this).tagSuggest({
       url: $.rootPath() + controllerName + '/autocomplete_tags',
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
    $('#spinner').show();
    $('body').css('cursor', 'progress');
  },
  hideGlobalSpinnerNode: function() {
    $('#spinner').hide();
    $('body').css('cursor', 'auto');
  },
  showMajorError: function(xhr) {
    //empty for now
  },
  getItemId: function(element) {
    return $(".singleitem").data("itemid");
  },
  toggleVisibilitySelector: function() {
    if ($('.privacy_toggle').attr("checked") == "checked"){
      $('#terms_require').html("<p class='inline-hints'>Submitting this item will allow others to see, copy, and create derivative works from this item in accordance with H2O's <a href=\"/p/terms\" target=\"_blank\">Terms of Service</a>.</p>")
    } else {
      $('#terms_require').html("<p class='inline-hints'>If this item is submitted as a non-public item, other users will not be able to see, copy, or create derivative works from it, unless you change the item's setting to \"Public.\" Note that making a previously \"public\" item non-public will not affect copies or derivatives made from that public version.</p>");
    }
  },

  /* 
  This is a generic UI function that applies to all elements with the "icon-delete" class.
  With this, a dialog box is generated that asks the user if they want to delete the item (Yes, No).
  When a user clicks "Yes", an ajax call is made to the link's href, which responds with JSON.
  The listed item is then removed from the UI.
  */
  observeDestroyControls: function(region){
    $(document).delegate('#generic_item_cancel', 'click', function(e) {
      e.preventDefault();
      $('#generic_item_form').slideUp(200, function() {
        $(this).remove();
      });
    });
    $(document).delegate('#generic_item_delete', 'click', function(e) {
      e.preventDefault();
      var destroyUrl = $(this).attr('href');
      var listing = $(this).parent().parent();
      var type = $(this).data('type');
      $.ajax({
        cache: false,
        type: 'POST',
        url: destroyUrl,
        dataType: 'JSON',
        data: {'_method': 'delete'},
        beforeSend: function() {
          $.showGlobalSpinnerNode();
        },
        error: function(xhr){
          $.hideGlobalSpinnerNode();
        },
        success: function(data){
          if($.classType() == 'playlists' && ($.cookie('playlists') != 'force_lookup' || user_playlists.length < 12)) {
            var user_new_playlists = []; 
            $.each(user_playlists, function(i, j) {
              if(j.playlist.id != data.id) {
                user_new_playlists.push(j);
              }
            });
            $.cookie('playlists', JSON.stringify(user_new_playlists), { path: '/' });
          }
          if($('.singleitem').length) {
            document.location.href = "/" + type + "s";
          } else {
            listing.slideUp(200, function(e) {
              listing.remove();
            });
            $.hideGlobalSpinnerNode();
          }
        }
      });
    });
    $(document).delegate(region + ' .icon-delete,' + region + '.delete-action', 'click', function(e){
      if($(this).parent().hasClass('delete-playlist-item')) {
        return;
      }

      // hide any existing forms
      e.preventDefault();
	    var type = $(this).data('type');
      var destroyUrl = $(this).attr('href');
      var listing;

      if($('.singleitem').length && $('.singleitem #description').has($(this)).length > 0) {
        listing = $('#description');
      } else {
        listing = $(this).parentsUntil('ul').last();
	      if(listing.find('#generic_item_form').size()) {
	        return;
	      }
	      $('#generic_item_form').slideUp(200, function() {
	        $(this).remove();
	      });
      }	

	    var data = { "url" : destroyUrl, "type" : type };
	    var content = $($.mustache(delete_item_template, data)).css('display', 'none');
	    content.appendTo(listing);
	    content.slideDown(200);
    });
  },

  /*
  Generic bookmark item, more details here.
  */
  updateExistingBookmarks: function() {
    if($.cookie('bookmarks') != null) {
      var bookmarks = $.parseJSON($.cookie('bookmarks'));
	    if($('.singleitem').size()) {
	      var key = $.classType().replace(/s$/, '') + $('.singleitem').data('itemid');
	      if($.inArray(key, bookmarks) != -1) {
	        var el = $('.bookmark-action');
	        el.removeClass('bookmark-action link-bookmark').addClass('delete-bookmark-action link-delete-bookmark').html('<span class="icon icon-delete-bookmark-large"></span>');
	        $('.delete-bookmark-action').attr('title', el.attr('title').replace(/^Bookmark/, 'Un-Bookmark'));
	      }
	    } else {
	      $.each(bookmarks, function(i, j) {
	        $('#listitem_' + j + ' .bookmark-action').removeClass('bookmark-action link-bookmark').addClass('delete-bookmark-action link-delete-bookmark').html('<span class="icon icon-delete-bookmark"></span>UN-BOOKMARK');
	      });
	    }
    }
  },
  observeBookmarkControls: function() {
    $(document).delegate('.bookmark-action', 'click', function(e){
      var item_url = $.rootPathWithFQDN() + 'bookmark_item/';
      var el = $(this);
      item_url += el.data('type') + '/' + el.data('itemid');
      e.preventDefault();
      $.ajax({
        cache: false,
        url: item_url,
        dataType: "JSON",
        data: {},
        beforeSend: function() {
          $.showGlobalSpinnerNode();
        },
        success: function(data) {
          $('.add-popup').hide();
          $.hideGlobalSpinnerNode();
   
          var bookmarks = $.parseJSON($.cookie('bookmarks'));
          bookmarks.push(el.data('type') + el.data('itemid'));
          $.cookie('bookmarks', JSON.stringify(bookmarks), { path: '/' });

          if($('.singleitem').size()) {
            $('.bookmark-action')
              .removeClass('bookmark-action link-bookmark')
              .addClass('delete-bookmark-action link-delete-bookmark')
              .html('<span class="icon icon-delete-bookmark-large"></span>')
              .attr('original-title', el.attr('original-title').replace(/^Bookmark/, 'Un-Bookmark'));
          } else {
            el.removeClass('bookmark-action link-bookmark').addClass('delete-bookmark-action link-delete-bookmark').html('<span class="icon icon-delete-bookmark"></span>UN-BOOKMARK');
          }
        },
        error: function(xhr, textStatus, errorThrown) {
          $.hideGlobalSpinnerNode();
        }
      });
    });
    $(document).delegate('.delete-bookmark-action', 'click', function(e){
      var el = $(this);
      var item_url = $.rootPathWithFQDN() + 'delete_bookmark_item/' + el.data('type') + '/' + el.data('itemid');

      e.preventDefault();
      $.ajax({
        cache: false,
        url: item_url,
        dataType: "JSON",
        data: {},
        beforeSend: function() {
          $.showGlobalSpinnerNode();
        },
        success: function(data) {
          $.hideGlobalSpinnerNode();
   
          var bookmarks = $.parseJSON($.cookie('bookmarks'));
          bookmarks.splice($.inArray(el.data('type') + el.data('itemid'), bookmarks), 1);
          $.cookie('bookmarks', JSON.stringify(bookmarks), { path: '/' });

          if($('body').hasClass('busers_show') && $('#results_bookmarks').has(el).length > 0) {
            var listitem = el.parentsUntil('#results_bookmarks').last();
            listitem.slideUp(200, function() {
              listitem.remove();
            });
          } else if($('.singleitem').size()) {
            $('.delete-bookmark-action')
              .removeClass('delete-bookmark-action link-delete-bookmark')
              .addClass('bookmark-action link-bookmark')
              .html('<span class="icon icon-favorite-large"></span>')
              .attr('original-title', el.attr('original-title').replace(/^Un-Bookmark/, 'Bookmark'));
          } else {
            el.removeClass('delete-bookmark-action link-delete-bookmark').addClass('bookmark-action link-bookmark').html('<span class="icon icon-bookmark"></span>BOOKMARK');
          }
        },
        error: function(xhr, textStatus, errorThrown) {
          $.hideGlobalSpinnerNode();
        }
      });
    });
  },
  observeRemixControls: function(region) {
    $(document).delegate('.remix-option-action', 'click', function(e) {
      e.preventDefault();
      var link = $(this);
      var data = { "copy_url" : link.attr('href'), "deep_copy_url": link.attr('href').replace(/copy/, 'deep_copy'), "type" : link.data('type'), "title" : link.data('title') }; 
      $($.mustache(remix_option_template, data)).dialog({
        title: 'Playlist Remix Options',
        modal: true,
        width: 'auto',
        height: 'auto'
      }).dialog('open');
    });
    $(document).delegate('.remix-action', 'click', function(e) {
      e.preventDefault();
      var link = $(this);
      var node_title = link.data('type').charAt(0).toUpperCase() + link.data('type').slice(1);
      if(node_title == 'Default') {
        node_title = 'Link';
      }
      var data = { "copy_url" : link.attr('href'), "node_title" : node_title, "type" : link.data('type'), "title" : link.data('title') }; 
      var html = $.mustache(remix_item_template, data);
      $.generateGenericNode(html);
    });
    $(document).delegate('.deep-remix-action', 'click', function(e) {
      e.preventDefault();
      var link = $(this);
      var node_title = link.data('type').charAt(0).toUpperCase() + link.data('type').slice(1);
      var data = { "copy_url" : link.attr('href'), "node_title" : node_title, "type" : link.data('type'), "title" : link.data('title') }; 
      var html = $.mustache(deep_remix_item_template, data);
      $.generateGenericNode(html);
    });
  },
  deep_remix_response: function(data) {
    $('#generic-node').dialog('close');
    var response = $('<p class="deep-remix-response">The system is remixing the playlist and every item in the playlist. You will be emailed when the process has completed.</p>');
    $('.deep-remix-action').replaceWith(response); 
    $.hideGlobalSpinnerNode();
  },
  /* Generic HTML form elements */
  observeGenericControls: function(region){
    $(document).delegate(region + ' .edit-action,' + region + ' .new-action,' + region + '.push-action', 'click', function(e){
      var actionUrl = $(this).attr('href');
      e.preventDefault();
      $.ajax({
        cache: false,
        url: actionUrl,
        beforeSend: function() {
          $.showGlobalSpinnerNode();
        },
        success: function(html) {
          $.hideGlobalSpinnerNode();
          $.generateGenericNode(html);
        },
        error: function(xhr, textStatus, errorThrown) {
          $.hideGlobalSpinnerNode();
        }
      });
    });
  },
  generateGenericNode: function(html) {
    $('#generic-node').remove();
    var newItemNode = $('<div id="generic-node"></div>').html(html);
    var title = '';
    if(newItemNode.find('#generic_title').length) {
      title = newItemNode.find('#generic_title').html();
    }
    $(newItemNode).dialog({
      title: title,
      modal: true,
      width: 'auto',
      height: 'auto',
      open: function(event, ui) {
        $.observeMarkItUpFields();
        if(newItemNode.find('#manage_playlists').length) {
          $('#manage_playlists #lookup_submit').click();
        }
        if(newItemNode.find('#manage_collages').length) {
          $('#manage_collages #lookup_submit').click();
        }
        if(newItemNode.find('#terms_require').length) {
          if(newItemNode.find('.privacy_toggle').length){
            $('.privacy_toggle').click(function(){
              $.toggleVisibilitySelector();
            });
          }
        }
        $.toggleVisibilitySelector();
      },
      buttons: {
        Submit: function() {
          $.submitGenericNode();
        },
        Close: function() {
          $(newItemNode).remove();
        }
      }
    }).dialog('open');
  },
  initiailizeUserPlaylists: function() {
    if($.cookie('playlists') == null || $.cookie('user_id') == null) {
      return;
    }
    if($.cookie('playlists') == 'force_lookup') {
      $.ajax({
        type: 'GET',
        dataType: 'json',
        url: '/users/' + $.cookie('user_id') + '/playlists',
        success: function(data) {
          user_playlists = $.parseJSON(data.playlists);
          $.each(user_playlists, function(i, j) {
            j.playlist.name = j.playlist.name.replace(/\+/g, ' ');
            $('#listitem_playlist' + j.playlist.id + ' .push-action').addClass('mark-for-keep');
          });
        }
      });
    } else {
      user_playlists = $.parseJSON($.cookie('playlists'));
      $.each(user_playlists, function(i, j) {
        j.playlist.name = j.playlist.name.replace(/\+/g, ' ');
        $('#listitem_playlist' + j.playlist.id + ' .push-action').addClass('mark-for-keep');
      });
    }
    $('.push-action:not(.mark-for-keep)').remove();
    $('.push-action').show();
  },
  submitGenericNode: function() {
    $('#generic-node #error_block').html('').hide();
    var buttons = $('#generic-node').parent().find('button');
    if(buttons.first().hasClass('inactive')) {
      return false;
    }
    buttons.addClass('inactive');
    $('#generic-node').find('form').ajaxSubmit({
      dataType: "JSON",
      beforeSend: function() {
        $.showGlobalSpinnerNode();
      },
      success: function(data) {
        if(data.error) {
          $('#generic-node #error_block').html(data.message).show(); 
          $.hideGlobalSpinnerNode();
          buttons.removeClass('inactive');
        } else {
          if(data.custom_block) {
            eval('$.' + data.custom_block + '(data)');
          } else {
            if(data.modify_playlists_cookie) {
              if(user_playlists.length < 10) {
                user_playlists.push({ "playlist" : { "id" : data.id, "name" : data.name } });
                $.cookie('playlists', JSON.stringify(user_playlists), { path: '/' });
              } else {
                $.cookie('playlists', 'force_lookup');
              }
            }
            setTimeout(function() {
              var redirect_to = $.rootPath() + data.type + '/' + data.id;
              var use_new_tab = $.cookie('use_new_tab');
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
        $.hideGlobalSpinnerNode();
      },
    });
  },
  push_playlist: function(data) {
    $.hideGlobalSpinnerNode();
    $('#generic-node').dialog('close');
    $('.main_wrapper').prepend($('<p>').attr('id', 'notice').html("Playlist is being pushed.  May take several minutes to complete. You'll receive an email when the push is completed."));
    window.scrollTo(0, 0);
  }

});

$(function() {
  $.cookie('return_to', document.location.pathname, { path: '/' });

  $.loadEditability();
  $.updateExistingBookmarks();
  $.initiailizeUserPlaylists();

  //Keep this early to adjust font sizes early
  $.adjustArticleHeaderSizes();

  $('#search form').on('submit', function() { 
    $("#search form").attr("action", "/" + $('select#search_all').val());
  });
  $('#search_button').on('click', function(e) {
    e.preventDefault();
    $('#search form').submit();
  });
  $('select#search_all').selectbox({
    className: "jsb", replaceInvisible: true 
  });

  /* Only used in collages */
  $.fn.observeField =  function( time, callback ){
    return this.each(function(){
      var field = this, change = false;
      $(field).keyup(function(){
        change = true;
      });
      setInterval(function(){
        if ( change ) callback.call( field );
        change = false;
      }, time * 1000);
    });
  }

  $(".link-more,.link-less").click(function(e) {
    $("#description_less,#description_more").toggle();
    e.preventDefault();
  });

  $('.item_drag_handle').button({icons: {primary: 'ui-icon-arrowthick-2-n-s'}});

  $('li.submit a').click(function() {
    $('form.search').submit();
  });

  if(document.location.hash.match('ajax_region=')) {
    var region = $('#results_' + $.address.parameter('ajax_region')).parent();
    region.find('.special_sort select').val($.address.parameter('sort'));
    var url = document.location.hash.replace(/^#/, '');
    $.listResultsSpecial(url, $.address.parameter('ajax_region'));
    $('html, body').animate({
      scrollTop: region.offset().top
    }, 100);
  } else if(document.location.hash.match('sort=')) {
    $('#results .sort select').val($.address.parameter('sort'));
    var url = document.location.hash.replace(/^#/, '');
    $.listResults(url, false);
  }

  $.initializeBarcodes();
  $.observeDestroyControls('');
  $.observeGenericControls('');
  $.observeRemixControls('');
  $.observeBookmarkControls();
  $.observePagination(); 
  $.observeSort();
  //$.observeCasesCollage();
  $.observeCasesVersions();
  $.observeTabDisplay();
  $.observeLoginPanel();
  $.observeResultsHover('');
  $.observeTabBehavior();
  $.loadEscapeListener();
  $.loadOuterClicks();
  $.observeViewerToggle();
  $.observeLoadMorePagination();
  $.initializeTooltips();
  $.observeCreatePopup();
  $.observeFontChange();
  $.observeMetadataForm();
  $.observeMetadataDisplay();
  $.observeQuickCollage();
  $.initializeRightPanelScroll();
  $.resetRightPanelThreshold();
  $.observeDefaultPrintListener();
  $.observeDefaultDescriptionShow();

  if($('body').hasClass('action_index')) {
    $.setListLinkVisibility();
  }

  if($.classType() != 'collages' && $.classType() != 'playlists') {
    $.setFixedLinkPosition();
  }

  $.address.externalChange(function(event) {
    if($('#results_set').size() && list_results_url != '') {
      if(event.value == '/') {
        if(list_results_url.match('ajax_region')) {
          var region = list_results_url.match(/ajax_region=[a-z_]*/).toString().replace(/ajax_region=/, '');
          var sort = $('.special_sort[data-region=' + region + '] select');
          $.resetSort('karma', sort);
          $.listResultsSpecial(document.location.pathname + '?ajax_region=' + region + '&order=desc&page=1&sort=karma', region, false);
        } else {
          var sort = $('.sort');
          $.resetSort('karma', sort);
          $('#user_keywords').val(keyword_value);
          if(list_results_url.match('media_type=')) {
            var media_type = list_results_url.match(/media_type=[a-z]*/).toString().replace(/media_type=/, '');
            $.listResults(document.location.pathname + '?media_type=' + media_type + '&order=desc&page=1&sort=karma', false);
          } else {
            $.listResults(document.location.pathname + '?order=desc&page=1&sort=karma', false);
          }
        }
      } else if(event.value.match('ajax_region')) {
        var sort_value = $.address.parameter('sort');
        var region = $.address.parameter('ajax_region');
        var sort = $('.special_sort[data-region=' + region + '] select');
        $.resetSort(sort_value, sort);
        $.listResultsSpecial(event.value, region, false);
      } else {
        if(event.value.match(/^\/users/)) {
          var keyword_value = $.address.parameter('keywords');
          $('#user_keywords').val(keyword_value);
        }
        var sort_value = $.address.parameter('sort');
        var sort = $('.sort');
        $.resetSort(sort_value, sort);
        $.listResults(event.value, false);
      }
    }
  });

  $.observeHomePageBehavior();
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

var delete_item_template = '\
<div id="generic_item_form" class="delete">\
<p>Are you sure you want to delete this item?</p>\
<a href="{{url}}" data-type="{{type}}" id="generic_item_delete" class="button">YES</a>\
<a href="#" id="generic_item_cancel" class="button">NO</a>\
</div>\
';

var remix_option_template = '\
<div id="playlist_remix_options">\
<a href="{{deep_copy_url}}" class="button deep-remix-action" data-type="playlist" data-title="{{title}}">Your own version of EVERY item in this playlist</a>\
<a href="{{copy_url}}" class="button remix-action" data-type="playlist" data-title="{{title}}">Your own version of the top-level only of the playlist</a>\
</div>';

var remix_item_template = '\
<h3 id="generic_title">Remix {{node_title}}</h3>\
<div id="error_block"></div>\
<form action="{{copy_url}}" class="{{type}}_form formtastic formtastic {{type}}" method="post">\
<fieldset class="inputs">\
<ol>\
<li class="string required" id="{{type}}_name_input">\
<label for="{{type}}_name">Name<abbr title="required">*</abbr></label>\
<input class="ui-widget-content ui-corner-all" id="{{type}}_name" maxlength="250" name="{{type}}[name]" size="50" type="text" value="{{title}}">\
</li>\
<li class="boolean required" id="{{type}}_public_input">\
<label for="{{type}}_public">\
<input name="{{type}}[public]" type="hidden" value="0"><input class="privacy_toggle" id="{{type}}_public" name="playlist[public]" checked="checked" type="checkbox" value="1">Public<abbr title="required">*</abbr></label>\
</li>\
<li class="text optional" id="{{type}}_description_input">\
<label for="{{type}}_description">Description</label>\
<textarea class="ui-widget-content ui-corner-all" cols="40" id="{{type}}_description" name="{{type}}[description]" rows="5"></textarea>\
</li>\
</ol></fieldset>\
</form>\
';

var deep_remix_item_template = '\
<h3 id="generic_title">Remix {{node_title}}</h3>\
<div id="error_block"></div>\
<form action="{{copy_url}}" class="{{type}}_form formtastic formtastic {{type}}" method="post">\
<fieldset class="inputs">\
<ol>\
<li class="string required" id="{{type}}_name_input">\
<label for="{{type}}_name">Name<abbr title="required">*</abbr></label>\
<input class="ui-widget-content ui-corner-all" id="{{type}}_name" maxlength="250" name="{{type}}[name]" size="50" type="text" value="{{title}}">\
</li>\
<li class="boolean required" id="{{type}}_public_input">\
<label for="{{type}}_public">\
<input name="{{type}}[public]" type="hidden" value="0"><input class="privacy_toggle" id="{{type}}_public" name="playlist[public]" checked="checked" type="checkbox" value="1">Public<abbr title="required">*</abbr></label>\
<small>This applies to EVERY item created.</small>\
</li>\
</ol></fieldset>\
</form>\
';
