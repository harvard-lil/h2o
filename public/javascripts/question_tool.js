/* goo-goo gajoob */
jQuery(function(){
    jQuery.extend({

      observeNewReplyControls: function(){
        jQuery('#new-reply-form').dialog({
          bgiframe: true,
          autoOpen: false,
          minWidth: 300,
          width: 450,
          modal: true,
          title: 'Add a reply',
          buttons: {
            'Add a reply': function(){
              jQuery('#new_reply').ajaxSubmit({
                error: function(xhr){jQuery('#new-reply-error').show().append(xhr.responseText);},
                beforeSend: function(){jQuery('#new-reply-error').html('').hide();},
                success: function(responseText){
                  jQuery.updateQuestionInstanceView(1,responseText);
                  jQuery('#new-reply-form').dialog('close');
                }
              });
              
            },
            'Cancel': function(){
              jQuery(this).dialog('close');
            }
          }
        });
        jQuery("a[id*='new-reply-on']").click(function(e){
          e.preventDefault();
          var questionId = jQuery(this).attr('id').split('-')[3];
          jQuery.ajax({
            type: 'GET',
            url: jQuery.rootPath() + 'replies/new?reply[question_id]=' + questionId,
            success: function(html){
              jQuery('#new-reply-form').html(html);
              jQuery('#new-reply-form').dialog('open');
            }
          });
        });
        
      },

      observeNewQuestionControl: function(){
        jQuery('a.new-question-for').each(function(){
          var questionInstanceId = jQuery(this).attr('id').split('-')[3];
          jQuery('#new-question-form-for-' + questionInstanceId).dialog({
            bgiframe: true,
            autoOpen: false,
            minWidth: 300,
            width: 450,
            modal: true,
            title: 'Add a question',
            buttons: {
              'Ask Question': function(){
                jQuery('#new-question-form-for-' + questionInstanceId + ' form ').ajaxSubmit({
                    error: function(xhr){jQuery('#new-question-error-' + questionInstanceId).show().append(xhr.responseText);},
                    beforeSend: function(){jQuery('#new-question-error-' + questionInstanceId).html('').hide()},
                    success: function(responseText){
                      jQuery.updateQuestionInstanceView(questionInstanceId,responseText)
                      jQuery('#new-question-form-for-' + questionInstanceId).dialog('close');
                    }
                  });
              },
              'Cancel': function(){
                jQuery('#new-question-error-' + questionInstanceId).html('').hide();
                jQuery(this).dialog('close');
              }
            }
          });
          jQuery(this).click(function(e){
            e.preventDefault();
            jQuery('#new-question-form-for-' + questionInstanceId).dialog('open');
          });
        });
      },

      observeVoteControls: function() {
        jQuery("a[id*='vote-for']").click(function(){
          var questionInstanceId = jQuery(this).attr('id').split('-')[2];
          var questionId = jQuery(this).attr('id').split('-')[3];
          jQuery.ajax({
            type: 'POST',
            url: jQuery.rootPath() + 'questions/vote_for',
            data: {question_id: questionId, authenticity_token: AUTH_TOKEN},
            beforeSend: function(){jQuery('#ajax-error-' + questionInstanceId).html('').hide()},
            error: function(xhr){jQuery('#ajax-error-' + questionInstanceId).show().append(xhr.responseText);}
          });
          //TODO - have this poll before just blindly doing the update.
          jQuery.updateQuestionInstanceView(questionInstanceId,questionId);
          return false;
          });
        },

      updateQuestionInstanceView: function(questionInstanceId,questionId){
        jQuery.ajax({
          type: 'GET',
          url: jQuery.rootPath() + 'question_instances/' + questionInstanceId + '?updated_question_id=' + questionId,
          data: {updated_question_id: questionId},
          success: function(html){
            jQuery('#questions-' + questionInstanceId).html(html); 
            jQuery.observeVoteControls();
            jQuery.observeNewReplyControls();
            jQuery('div.updated').stop().css("background-color", "#FFFF9C").animate({ backgroundColor: "#FFFFFF"}, 2000);
          }
        });
      }
  });

    jQuery(document).ready(function(){
      jQuery.observeVoteControls();
      jQuery.observeNewQuestionControl();
      jQuery.observeNewReplyControls();
  });
});
