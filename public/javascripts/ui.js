/* I am the walrus! */

$.noConflict();

jQuery(function() {

    function updateTips(t) {
        tips.text(t).effect("highlight",{},1500);
    }

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

    jQuery.fn.observeForm =  function( time, callback ){
	    return this.each(function(){
	        var form = this, change = false;
	        jQuery(form.elements).keyup(function(){
	            change = true;
	        });
	        setInterval(function(){
	            if ( change ) callback.call( form );
	            change = false;
	        }, time * 1000);
	    });
	}

  jQuery.extend({
    rootPath: function(){
      return '/';
    },

    initCanvas: function(el){
      if(el.getContext){
        //already there
      } else {
        G_vmlCanvasManager.initElement(el);
      }
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
	});
	
	jQuery('#results .song details .influence input').rating();
	jQuery('#playlist details .influence input').rating();
	
	jQuery("#results .listitem .controls ul li.link-add").click(function() {
		jQuery(this).parents(".listitem").toggleClass("song-active").find(".add-popup").toggle();
		
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
		jQuery(this).parents(".btn-li").find(".popup").toggle();
		jQuery(this).toggleClass("btn-a-active");
		
		return false;
	});


	jQuery(".search_all input[type=radio]").click(function() {
		jQuery(".search_all form").attr("action", "/" + jQuery(this).val());
	});
	jQuery("#search_all_radio").click();

	jQuery(".tabs a").click(function() {
		jQuery(".tabs a").removeClass("active");
		jQuery('.' + jQuery('.tabs').parent().attr("id").replace(/_hgroup/, "") + "_section").hide();
		jQuery("#" + jQuery(this).attr('id').replace(/_link$/, "")).show();
		jQuery(this).addClass("active");
	});

	jQuery(".link-more").click(function() {
		jQuery("#description_less").hide();
		jQuery("#description_more").show();
	});
	jQuery(".link-less").click(function() {
		jQuery("#description_more").hide();
		jQuery("#description_less").show();
	});
});
