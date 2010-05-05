jQuery(function(){
    jQuery.extend({
      observeQuestionInstanceControl: function(){
        /* Observe parts of the question instance list. Set up the edit / new jQuery.dialog(), 
           set up the dispatch URL and then update / reobserve upon successful submission.
        */
        jQuery('a.question-instance-control').click(function(e){
          if(jQuery('#logged-in').length > 0){
            e.preventDefault();
            var dispatchUrl = '';
            if(jQuery(this).attr('id').match(/^edit\-question\-instance/) ){
              var question_instance_id = jQuery(this).attr('id').split('-')[3];
              dispatchUrl = jQuery.rootPath() + 'question_instances/' + question_instance_id + '/edit'
            } else {
              dispatchUrl = jQuery.rootPath() + 'question_instances/new'
            }
            jQuery.ajax({
              type: 'GET',
              url: dispatchUrl,
              beforeSend: function(){
                jQuery('#spinner_block').show();
              },
              success: function(html){
                jQuery('#spinner_block').hide();
                jQuery('#question-instance-form-container').html(html);
                jQuery('#question-instance-form-container').dialog('open');
              }
            });
  
            jQuery('#question-instance-form-container').dialog({
              bgiframe: true,
              autoOpen: false,
              minWidth: 300,
              width: 450,
              modal: true,
              title: 'Question Tool',
              buttons: {
                'Save Question Tool': function(){
                  jQuery('#question-instance-form').ajaxSubmit({
                    error: function(xhr){
                      jQuery('#spinner_block').hide();
                      jQuery('#question-instance-error').show().append(xhr.responseText);
                    },
                    beforeSend: function(){
                      jQuery('#spinner_block').show();
                      jQuery('#question-instance-error').html('').hide();
                    },
                    success: function(responseText){
                      jQuery('#spinner_block').hide();
                      jQuery.ajax({
                        type: 'GET',
                        url: jQuery.rootPath() + 'question_instances',
                        beforeSend: function(){
                          jQuery('#spinner_block').show();
                        },
                        success: function(html){
                          window.location.href = jQuery.rootPath() + 'question_instances?updated=1';
                        },
                        error: function(xhr){
                          jQuery('#spinner_block').hide();
                          jQuery('#question-instance-error').show().append(xhr.responseText);
                        }
                      });
                      jQuery('#question-instance-form-container').dialog('close');
                    }
                  });
                },
                'Cancel': function(){
                  jQuery('#question-instance-error').html('').hide();
                  jQuery(this).dialog('close');
                }
              }
            });
          }
        });
      }
    });

    jQuery(document).ready(function(){
      jQuery('#question_instance_submit').button({icons: {primary: 'ui-icon-circle-plus'}});
      jQuery.observeQuestionInstanceControl();
      if(jQuery('#question-instance-chooser').length > 0){
        jQuery("#question-instance-chooser").tablesorter();
      }
   });
});
