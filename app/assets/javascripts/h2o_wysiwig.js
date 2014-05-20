var tinyMCEPreInit = {
  mceInit : {
    'content':{
      relative_urls: false,
      convert_urls: false,
      mode: "textareas",
      menubar: false,
      toolbar1: "bold italic strikethrough | bullist numlist blockquote | alignleft aligncenter alignright | link unlink | formatselect underline alignjustify forecolor | pastetext pasteword removeformat | charmap | outdent indent | undo redo help | fullscreen",
      theme_advanced_toolbar_location:"top",
      theme_advanced_toolbar_align:"left",
      theme_advanced_statusbar_location:"bottom",
      theme_advanced_resizing:true,
      theme_advanced_resize_horizontal:false,
      plugins:"fullscreen,link,charmap,textcolor",
      add_form_submit_trigger: false,
      skin_url: 'http://tinymce.cachefly.net/4.0/skins/lightgray'
    }
  } ,
  qtInit : {
    'content': {
      id:"content",
      buttons:"strong,em,link,block,del,ins,img,ul,ol,li,code,more,spell,close,fullscreen"
    },
    'replycontent':{
      id:"replycontent",
      buttons:"strong,em,link,block,del,ins,img,ul,ol,li,code,spell,close"
    }
  } 
};

jQuery(document).ready(function(){
  if($('body').data('controller') == 'medias' || $('body').data('controller') == 'users' || $('body').data('action') == 'show') {
    return;
  }
  var init, ed, qt, first_init, mce = false;

  if ( typeof(tinymce) == 'object' ) {
    for ( ed in tinyMCEPreInit.mceInit ) {
      if ( first_init ) {
        init = tinyMCEPreInit.mceInit[ed] = tinymce.extend( {}, first_init, tinyMCEPreInit.mceInit[ed] );
      } else {
        init = first_init = tinyMCEPreInit.mceInit[ed];
      }

      try { tinymce.init(init); } catch(e){}
    }
  }

  if ( typeof(QTags) == 'function' ) {
    for ( qt in tinyMCEPreInit.qtInit ) {
      try { quicktags( tinyMCEPreInit.qtInit[qt] ); } catch(e){}
    }
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
});
