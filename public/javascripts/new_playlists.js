jQuery.extend({
  submitPlaylist: function(className){
    jQuery('#playlist-editor').find('form').ajaxSubmit({
      dataType: 'script',
      beforeSend: function(){
        jQuery('#error_block').hide();
      },
      success: function(response){
        jQuery('#playlist-editor').dialog('close');
        document.location.href = jQuery.rootPath() + 'playlists/'
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
  },
  initPlaylistDeleteControls: function(){
    jQuery('.delete-playlist').click(function(e){
        var url = jQuery(this).attr('href');
        e.preventDefault();
        var confirmNode = jQuery('<div>Are you sure you want to delete this playlist?</div>');
        jQuery(confirmNode).dialog({
          title: 'Are you sure you want to delete this playlist?',
          modal: true,
          position: 'top',
          width: 500,
          close: function(){
            jQuery(confirmNode).remove();
          },
          buttons: {
            Yes: function(){
              jQuery.ajax({
                type: 'POST',
                dataType: 'script',
                url: url,
                data: {'_method': 'DELETE'},
                success: function(html){
                  document.location.href = jQuery.rootPath() + 'playlists/';
                },
                error: function(xhr){
                  jQuery(confirmNode).html(xhr.responseText);
                }
              });
            },
            No: function(){
              jQuery(confirmNode).dialog('close');
              jQuery(confirmNode).remove();
            }
          }
        });
    });
  }
    
});

jQuery(document).ready(function(){
    jQuery('.button').button();
    jQuery.initPlaylistEditControls('.new-playlist,.edit-playlist');
    jQuery.initPlaylistDeleteControls();
});
