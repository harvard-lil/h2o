jQuery(document).ready(function() {
  if(jQuery('input[name=text_block_journal_article]:checked').length) {
    //show clicked
  } else {
    jQuery('#text_block_v').attr('checked', true);
    jQuery('#journal-article-form').hide();
  }
  jQuery('input[name=text_block_journal_article]').click(function() {
    jQuery('.standard-form').hide();
    jQuery('#' + jQuery(this).val() + '-form').show();
  });
});
