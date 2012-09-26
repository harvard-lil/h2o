jQuery(function() {
  if(document.location.hash) {
    var el = jQuery('.tabs a[data-region=' + document.location.hash.replace(/#p_/, 'all_') + '],.tabs a[data-region=' + document.location.hash.replace(/#p_/, '') + ']');
    el.click(); 
  }
  jQuery('.tabs a').click(function() {
    document.location.hash = 'p_' + jQuery(this).data('region').replace('all_', '');
  });
  if(jQuery('.tabs').height() > 30) {
    jQuery('#results .tabs li a').css('padding', '0px 7px 2px');
  }
});
