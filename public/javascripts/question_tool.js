/* goo-goo gajoob */

jQuery(function(){

    jQuery.extend({
      observeVoteControls: function() {
        jQuery("a[id*='vote-for']").click(function(){
          var elementId = jQuery(this).attr('id').split('-')[2];

//          jQuery.ajax({
//            url: 'ajax/test.html',
//            success: function(data) {
//              $('.result').html(data);
//              alert('Load was performed.');
//            }
//          });

//          jQuery
          return false;
          });
        }
    });

    jQuery(document).ready(function(){
      jQuery.observeVoteControls();
      });

    });
