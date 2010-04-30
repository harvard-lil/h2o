/* I am the walrus! */

$.noConflict();

jQuery(function() {
    function updateTips(t) {
        tips.text(t).effect("highlight",{},1500);
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

  //Fire functions for discussions
  initDiscussionControls();

});

jQuery(document).ready(function(){
    jQuery('.loaded-via-xhr #anon-login').live('click', function(e){ 
      e.preventDefault();
      jQuery.ajax({
        type: 'GET',
        url: jQuery(this).attr('href'),
        success: function(html){
          jQuery.ajax({
            type: 'GET',
            url: html,
            success: function(innerHtml){
              jQuery('#login-form').html(innerHtml);
            }
          });
        }
      });
    });

});
