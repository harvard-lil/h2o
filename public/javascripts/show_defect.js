
jQuery(document).ready(function() {
     jQuery('.show-action').click(function(e) {
		e.preventDefault(); 
        jQuery(this).parent().parent().parent().children('.show-defect').dialog({width:600, height:400});
     });
});
