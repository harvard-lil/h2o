/* I am the walrus! */

$.noConflict();

jQuery(function() {
    function updateTips(t) {
        tips.text(t).effect("highlight",{},1500);
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
      return '/'
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

