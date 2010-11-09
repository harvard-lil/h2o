jQuery.extend({
  observePagination: function(){
    jQuery('.pagination a').click(function(e){
      e.preventDefault();
      jQuery.ajax({
        type: 'GET',
        dataType: 'script',
        url: jQuery(this).attr('href'),
        success: function(html){
          jQuery('#text_block-list').html(html);
          jQuery('.tablesorter').tablesorter();
          jQuery('.button').button();
          jQuery.observePagination();
        }
      });
    });
  }
});

jQuery(document).ready(function(){
  jQuery.observeToolbar();
  jQuery('.button').button();

  if(jQuery('#text_block_description').length > 0 ){
    if(jQuery('#text_block_mime_type').val() == 'text/plain'){
      jQuery("#text_block_description").markItUp(myTextileSettings);
    } else if(jQuery('#text_block_mime_type').val() == 'text/html'){
      jQuery("#text_block_description").markItUp(myHtmlSettings);
    }
  }

  jQuery('#text_block_mime_type').change(function(e){
    e.preventDefault();
    if(jQuery(this).val() == 'text/plain'){
      jQuery('#text_block_description').markItUpRemove();
      jQuery("#text_block_description").markItUp(myTextileSettings);
    } else if(jQuery(this).val() == 'text/html'){
      jQuery('#text_block_description').markItUpRemove();
      jQuery("#text_block_description").markItUp(myHtmlSettings);
    } else {
      jQuery('#text_block_description').markItUpRemove();
    }
  });

  jQuery('.per-page-selector').change(function(){
    jQuery.cookie('per_page', jQuery(this).val(), {expires: 365});
    document.location = document.location;
  });
  jQuery('.per-page-selector').val(jQuery.cookie('per_page'));
  jQuery.observeTagAutofill('.tagging-autofill-tags','text_blocks');
  jQuery('.tablesorter').tablesorter();
  jQuery.observePagination();
  jQuery.observeMetadataForm();


});
