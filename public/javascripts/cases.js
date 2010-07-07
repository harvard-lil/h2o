jQuery(document).ready(function(){
    jQuery.observeToolbar();
    jQuery('.button').button();
    jQuery('.tablesorter').tablesorter();

    jQuery('.per-page-selector').change(function(){
      jQuery.cookie('per_page', jQuery(this).val(), {expires: 365});
        document.location = document.location;
    });
    jQuery('.per-page-selector').val(jQuery.cookie('per_page'));

    if(jQuery('.tagging-autofill-tags').length > 0){
      jQuery(".tagging-autofill-tags").live('click',function(){
        jQuery(this).tagSuggest({
          url: jQuery.rootPath() + 'cases/autocomplete_tags',
          separator: ', ',
          delay: 500
        });
      });
    }
});
