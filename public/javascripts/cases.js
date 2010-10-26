jQuery(document).ready(function(){
    jQuery.observeToolbar();
    jQuery('.button').button();

    jQuery('.per-page-selector').change(function(){
      jQuery.cookie('per_page', jQuery(this).val(), {expires: 365});
        document.location = document.location;
    });
    jQuery('.per-page-selector').val(jQuery.cookie('per_page'));
    jQuery.observeTagAutofill('.tagging-autofill-tags','cases');

});
