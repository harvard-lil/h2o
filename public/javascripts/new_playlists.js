jQuery.extend({
  submitPlaylist: function(className){
    jQuery('#playlist-editor').find('form').ajaxSubmit({
      dataType: 'script',
      beforeSend: function(){
        jQuery('#error_block').hide();
      },
      success: function(response){
        jQuery('#playlist-editor').dialog('close');
        if(console){
          console.log(response);
        }
        document.location = jQuery.rootPath() + 'playlists/'
      },
      error: function(xhr){
        jQuery('#error_block').show().html(xhr.responseText);
      }
    });
  },

  initPlaylistEditControls: function(className){
      jQuery(className).click(function(e){
        e.preventDefault();
        jQuery.ajax({
          cache: false,
          dataType: 'script',
          url: jQuery(this).attr('href'),
          success: function(html){
            var newPlaylistNode = jQuery('<div id="playlist-editor"></div>');
            jQuery(newPlaylistNode).dialog({
                modal: true,
                width: 500,
                height: 400,
                position: 'top',
                close: function(){
                  jQuery(newPlaylistNode).remove();
                }, 
                buttons: {
                  Save: function(){
                    jQuery.submitPlaylist(className);
                  },
                  Close: function(){
                    jQuery(newPlaylistNode).dialog('close');
                  }
                }
              });
            jQuery(newPlaylistNode).html(html);
            jQuery(newPlaylistNode).dialog('open');
          }
        });
      });
  }
    
});

jQuery(document).ready(function(){
    jQuery('.button').button();
    jQuery.initPlaylistEditControls('.new-playlist');
});
