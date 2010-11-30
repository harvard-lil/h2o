jQuery.extend({
  observePagination: function(){
    jQuery('.pagination a').click(function(e){
      e.preventDefault();
      jQuery.ajax({
        type: 'GET',
        dataType: 'script',
        url: jQuery(this).attr('href'),
        success: function(html){
          jQuery('#case-list').html(html);
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
  jQuery('#case_content').markItUp(myHtmlSettings);
  jQuery('.buttons .create, .buttons .update').button();

  jQuery('.per-page-selector').change(function(){
    jQuery.cookie('per_page', jQuery(this).val(), {expires: 365});
    document.location = document.location;
  });
  jQuery('.per-page-selector').val(jQuery.cookie('per_page'));
  jQuery.observeTagAutofill('.tagging-autofill-tags','cases');
  jQuery.observePagination();
});
