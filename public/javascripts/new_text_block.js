jQuery(document).ready(function() {
  jQuery('#journal_article_publish_date, #text_block_metadatum_attributes_date').datepicker({
    changeMonth: true,
    changeYear: true,
    yearRange: 'c-300:c',
    dateFormat: 'yy-mm-dd'
  });
  if(jQuery('#input_type').length) {
    if(jQuery('input[name=text_block_journal_article]:checked').length) {
      var clicked_form = '#' + jQuery('input[name=text_block_journal_article]:checked').val() + '-form';
  
      //Important: We need this to happen on a delay, so wysiwig editor has correct width
      setTimeout(function() {
        jQuery('.standard-form').hide();
        jQuery(clicked_form).show();
      }, 500);
    } else {
      jQuery('#text_block_v').attr('checked', true);
  
      //Important: We need this to happen on a delay, so wysiwig editor has correct width
      setTimeout(function() {
        jQuery('#journal-article-form').hide();
      }, 500);
    }
    jQuery('input[name=text_block_journal_article]').click(function() {
      jQuery('.standard-form').hide();
      jQuery('#' + jQuery(this).val() + '-form').show();
    });
  }
  jQuery('.privacy_toggle').click(function(){
    if (jQuery(this).attr("checked") == "checked"){
      jQuery('#terms_require').html("Submitting this item will allow others to see, copy, and create derivative works from this item in accordance with H2O's <a href=\"/p/terms\" target=\"_blank\">Terms of Service</a>.")
    } else {
      jQuery('#terms_require').html("<p style='text-align:left'>If this item is submitted as a non-public item, other users ill not be able to see, copy, or create derivative works from it, unless you change the item's setting to \"Public.\".</p>");
    }
  });  

});
