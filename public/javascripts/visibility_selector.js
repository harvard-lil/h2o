function toggleTerms(){
  if (jQuery('.privacy_toggle').attr("checked") == "checked"){
    jQuery('#terms_require').html("<p class='inline-hints'>Submitting this item will allow others to see, copy, and create derivative works from this item in accordance with H2O's <a href=\"/p/terms\" target=\"_blank\">Terms of Service</a>.</p>")
    } else {
    jQuery('#terms_require').html("<p class='inline-hints'>If this item is submitted as a non-public item, other users ill not be able to see, copy, or create derivative works from it, unless you change the item's setting to \"Public.\".</p>");
  }
}
jQuery(document).ready(function() {

  jQuery('.privacy_toggle').click(function(){
    toggleTerms();
  });  
  toggleTerms(); 
});

