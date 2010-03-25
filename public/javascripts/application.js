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

  //Fire functions for discussions
  initDiscussionControls();

});
