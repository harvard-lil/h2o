var tinyMCEPreInit = {
			mceInit : {
        'content':{
          mode: "textareas",
          theme:"advanced",
          theme_advanced_buttons1:"bold,italic,strikethrough,|,bullist,numlist,blockquote,|,justifyleft,justifycenter,justifyright,|,link,unlink,|,kitchen_sink",
          theme_advanced_buttons2:"formatselect,underline,justifyfull,forecolor,|,pastetext,pasteword,removeformat,|,charmap,|,outdent,indent,|,undo,redo,help",
          theme_advanced_buttons3:"",
          theme_advanced_buttons4:"",
          theme_advanced_toolbar_location:"top",
          theme_advanced_toolbar_align:"left",
          theme_advanced_statusbar_location:"bottom",
          theme_advanced_resizing:true,
          theme_advanced_resize_horizontal:false,
          plugins:"tabfocus,paste,kitchen_sink,moretag,",
          add_form_submit_trigger: false,
          formats: {
            bold: { inline: 'b', 'classes': 'bold' }
          }
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

      jQuery('#mce_switches a').click(function() {
        if(jQuery(this).hasClass('current')) {
          return false;
        } 
        jQuery('#mce_switches a.current').removeClass('current');
        jQuery(this).addClass('current');

        switchEditors.switchto(jQuery(this).attr('id'));

        return false;
      });
});
