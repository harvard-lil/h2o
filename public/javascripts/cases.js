jQuery(document).ready(function(){
    jQuery('.tablesorter').tablesorter();
    jQuery('.button').button();

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
