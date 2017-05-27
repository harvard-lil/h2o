var h2o_mceInit = {
      relative_urls: false,
      convert_urls: false,
      mode: "textareas",
      menubar: false,
      toolbar1: "bold italic strikethrough underline | bullist numlist blockquote | alignleft aligncenter alignright | link unlink | fontsizeselect formatselect alignjustify forecolor | pastetext removeformat | charmap | outdent indent | undo redo",
      fontsize_formats: "16px 20px 24px 28px 32px",
      theme_advanced_toolbar_location:"top",
      theme_advanced_toolbar_align:"left",
      theme_advanced_statusbar_location:"bottom",
      theme_advanced_resizing:true,
      theme_advanced_resize_horizontal:false,
      plugins:"fullscreen,link,charmap,textcolor,paste",
      add_form_submit_trigger: false,
      skin_url: '/assets',
      content_css: '/h2o_tinymce.css,/assets/tinymce.woff',
      editor_deselector: 'no_tinymce'
};
var h2o_mceInit_abbr = {
      relative_urls: false,
      convert_urls: false,
      mode: "textareas",
      menubar: false,
      toolbar1: "bold italic | bullist numlist | link unlink | formatselect | pastetext removeformat | charmap | undo redo",
      fontsize_formats: "16px 20px 24px 28px 32px",
      theme_advanced_toolbar_location:"top",
      theme_advanced_toolbar_align:"left",
      theme_advanced_statusbar_location:"bottom",
      theme_advanced_resizing:true,
      theme_advanced_resize_horizontal:false,
      plugins:"link,charmap,paste",
      add_form_submit_trigger: false,
      skin_url: '/assets',
      content_css: '/h2o_tinymce.css',
      editor_deselector: 'no_tinymce'
};

jQuery(document).ready(function(){
  if($('body').data('action') == 'show') {
    return;
  }
  var init, ed, qt, first_init, mce = false;

  if ( typeof(tinymce) == 'object' ) {
    try { tinymce.init(h2o_mceInit); } catch(e) {}
  }

  jQuery('.mce_switches a').click(function() {
    if(jQuery(this).hasClass('current')) {
      return false;
    }
    jQuery(this).siblings('a.current').removeClass('current');
    jQuery(this).addClass('current');

    switchEditors.switchto(jQuery(this).attr('id'));

    return false;
  });
  jQuery('#case_submit_action button, #text_block_submit_action button, #default_submit_action button').click(function(){
    if(!jQuery('.mce_switches .html').hasClass('active')) {
      switchEditors.switchto(jQuery('.mce_switches .html').attr('id'));
    }
  });

  if($('body').attr('id') == 'text_blocks_new') {
    $('li#text_block_description_input > div').hide();
    $('li#text_block_description_input > textarea').show();
  }
});
