/* I am the walrus! */

$.noConflict();

/*
jQuery(document).ready(function(){
    if(jQuery("#question-instance-chooser")){
        jQuery("#question-instance-chooser").tablesorter();
    }
});
*/

jQuery(function() {
    function updateTips(t) {
        tips.text(t).effect("highlight",{},1500);
    }

  jQuery.extend({
    rootPath: function(){
      return '/'
    }
  });
 

  

});


