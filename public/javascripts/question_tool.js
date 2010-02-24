/* goo-goo gajoob */

jQuery(function(){

    jQuery.extend({
      observeVoteControls: function() {
        jQuery("a[id*='vote-for']").click(function(){
          var elementId = jQuery(this).attr('id').split('-')[2];
          alert(elementId);
          return false;
          });
        }
    });

    jQuery(document).ready(function(){
      jQuery.observeVoteControls();
      });

    });
