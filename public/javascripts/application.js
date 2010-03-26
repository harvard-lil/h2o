/* I am the walrus! */

$.noConflict();

jQuery(function() {
    function updateTips(t) {
        tips.text(t).effect("highlight",{},1500);
    }

  jQuery.extend({
    rootPath: function(){
      return '/'
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
