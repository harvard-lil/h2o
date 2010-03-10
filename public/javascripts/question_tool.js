/* goo-goo gajoob */
jQuery(function(){
    jQuery.extend({
      observeShowReplyControls: function(){
        jQuery("a[id*='show-replies-on']").click(function(e){
            e.preventDefault();
            var questionId = jQuery(this).attr('id').split('-')[3];
            var repliesContainer = jQuery('#replies-container-' + questionId);
            if(repliesContainer.html().length > 0 && repliesContainer.is(':visible')){
              //There's content in here and it's visible. Just hide it.
              repliesContainer.toggle('fast');
            } else {
              //There's no content, or there's content and it's invisible. 
              //Get the replies again to ensure fresh content.
              jQuery.ajax({
                type: 'GET',
                url: jQuery.rootPath() + 'questions/replies/' + questionId,
                beforeSend: function(){jQuery('#spinner_block').show()},
                success: function(html){
                  jQuery('#spinner_block').hide();
                  repliesContainer.html(html).toggle('fast');
                },
                error: function(xhr){
                  jQuery('#spinner_block').hide();
                  jQuery('div.ajax-error').show().append(xhr.responseText);
                }
              });
            }
          });
      },

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
                error: function(xhr){
                  jQuery('#spinner_block').hide();
                  jQuery('#new-reply-error').show().append(xhr.responseText);
                },
                beforeSend: function(){
                  jQuery('#spinner_block').show();
                  jQuery('#new-reply-error').html('').hide();
                },
                success: function(responseText){
                  jQuery('#spinner_block').hide();
                  var rspArray = responseText.split(',')
                  jQuery.updateQuestionInstanceView(rspArray[0],rspArray[1]);
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
            beforeSend: function(){
              jQuery('#spinner_block').show();
            },
            success: function(html){
              jQuery('#spinner_block').hide();
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
                    error: function(xhr){
                      jQuery('#spinner_block').hide();
                      jQuery('#new-question-error-' + questionInstanceId).show().append(xhr.responseText);
                    },
                    beforeSend: function(){
                      jQuery('#spinner_block').show();
                      jQuery('#new-question-error-' + questionInstanceId).html('').hide();
                    },
                    success: function(responseText){
                      jQuery('#spinner_block').hide();
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
            beforeSend: function(){
              jQuery('#spinner_block').show();
              jQuery('#ajax-error-' + questionInstanceId).html('').hide();
            },
            error: function(xhr){
              jQuery('#spinner_block').hide();
              jQuery('#ajax-error-' + questionInstanceId).show().append(xhr.responseText);
            },
            success: function(){
              jQuery('#spinner_block').hide();
              //TODO - have this poll before just blindly doing the update.
              jQuery.updateQuestionInstanceView(questionInstanceId,questionId);
            }
          });
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
            jQuery.observeShowReplyControls();
            jQuery('div.updated').stop().css("background-color", "#FFFF9C").animate({ backgroundColor: "#FFFFFF"}, 2000);
          }
        });
      }
  });

    jQuery(document).ready(function(){
      jQuery.observeVoteControls();
      jQuery.observeNewQuestionControl();
      jQuery.observeNewReplyControls();
      jQuery.observeShowReplyControls();
  });
});
