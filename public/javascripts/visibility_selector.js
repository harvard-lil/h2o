function toggleTerms(){
  if ($('.privacy_toggle').attr("checked") == "checked"){
    $('#terms_require').html("<p class='inline-hints'>Submitting this item will allow others to see, copy, and create derivative works from this item in accordance with H2O's <a href=\"/p/terms\" target=\"_blank\">Terms of Service</a>.</p>")
    } else {
    $('#terms_require').html("<p class='inline-hints'>If this item is submitted as a non-public item, other users will not be able to see, copy, or create derivative works from it, unless you change the item's setting to \"Public.\" Note that making a previously \"public\" item non-public will not affect copies or derivatives made from that public version.</p>");
  }
}
$(document).ready(function() {
  $('.privacy_toggle').click(function(){
    toggleTerms();
  });  
  toggleTerms(); 
});

