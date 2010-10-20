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

  //Front page image hover
    jQuery("#question_logo").hover( function () {
        jQuery(this).attr('src', '/images/elements/question_hover.png');
      },
      function () {
        jQuery(this).attr('src', '/images/elements/question.png');
      }
    );

    jQuery("#rotisserie_logo").hover( function () {
        jQuery(this).attr('src', '/images/elements/cog_hover.png');
      },
      function () {
        jQuery(this).attr('src', '/images/elements/cog.png');
      }
    );

    jQuery("#playlist_logo").hover( function () {
        jQuery(this).attr('src', '/images/elements/playlist_hover.png');
      },
      function () {
        jQuery(this).attr('src', '/images/elements/playlist.png');
      }
    );

  //Fire functions for discussions
  initDiscussionControls();

});

