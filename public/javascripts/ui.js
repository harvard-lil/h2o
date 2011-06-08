/* I am the walrus! */

$.noConflict();

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

  jQuery.extend({
    rootPath: function(){
      return '/';
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
    }
  });

  //Fire functions for discussions
  initDiscussionControls();



	jQuery("#results .sort select").selectbox({
		className: "jsb"
	}).change(function() {
		window.location = jQuery(this).val();
	});
	
	jQuery('#results .song details .influence input').rating();
	jQuery('#playlist details .influence input').rating();

	jQuery(".link-add a").click(function() {
		var element = jQuery(this);
		var position = element.offset();
		var results_posn = jQuery('.popup').parent().offset();
		var left = position.left - results_posn.left;
		var current_id = element.attr('class');
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

	jQuery(".bookmark-this").click(function() {
		jQuery.ajax({
        	type: "post",
            dataType: "json",
            url: "/bookmark_item",
            data: {
				item: jQuery(".popup").data("item_id"),
				type: jQuery(".popup").data("type")
            },
			success: function() {
				alert('here');
			}
        });
		return false;
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
		jQuery('.' + jQuery('.tabs').parent().attr("id").replace(/_hgroup/, "") + "_section").hide();
		jQuery("#" + jQuery(this).attr('id').replace(/_link$/, "")).show();
		jQuery(this).addClass("active");
	});

	jQuery(".link-more,.link-less").click(function() {
		jQuery("#description_less,#description_more").toggle();
	});

    jQuery('.item_drag_handle').button({icons: {primary: 'ui-icon-arrowthick-2-n-s'}});

	/* TODO: Generic-ize this to work on multiple pages */
    jQuery(".sortable").sortable({
        handle: '.item_drag_handle',
        axis: 'y',
        helper: sortableCellHelper,
        update: function(event, ui) {
            var container_id = jQuery('#container_id').text();
            var playlist_order = jQuery(".sortable").sortable("serialize");
            jQuery.ajax({
                type: "post",
                dataType: 'json',
                url: '/playlists/' + container_id + '/position_update',
                data: {
                    playlist_order: playlist_order
                }
            });
		}
	}).disableSelection();

	jQuery('.link-copy').click(function() {
		jQuery(this).closest('form').submit();
	});
});
