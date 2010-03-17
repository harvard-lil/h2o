/* goo-goo gajoob */
jQuery(function(){
    jQuery.extend({
      observeShowReplyControls: function(){
        jQuery('a.show-replies').click(function(e){
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
                  jQuery.observeNewQuestionControl();
                },
                error: function(xhr){
                  jQuery('#spinner_block').hide();
                  jQuery('div.ajax-error').show().append(xhr.responseText);
                }
              });
            }
          });
      },

      observeNewQuestionControl: function(){
        jQuery('a.new-question-for').each(function(){
          var questionInstanceId = jQuery(this).attr('id').split('-')[3];
          var questionId = jQuery(this).attr('id').split('-')[4];
          jQuery(this).click(function(e){
            jQuery('#new-question-form').dialog({
              bgiframe: true,
              autoOpen: false,
              minWidth: 300,
              width: 450,
              modal: true,
              title: ((questionId == 0) ? 'Add a question' : 'Add a reply'),
              buttons: {
                'Ask Question': function(){
                  jQuery('#new-question-form form').ajaxSubmit({
                      error: function(xhr){
                        jQuery('#spinner_block').hide();
                        jQuery('#new-question-error').show().append(xhr.responseText);
                      },
                      beforeSend: function(){
                        jQuery('#spinner_block').show();
                        jQuery('#new-question-error').html('').hide();
                      },
                      success: function(responseText){
                        jQuery('#spinner_block').hide();
                        jQuery.updateQuestionInstanceView(questionInstanceId,responseText)
                        jQuery('#new-question-form').dialog('close');
                      }
                    });
                },
                'Cancel': function(){
                  jQuery('#new-question-error').html('').hide();
                  jQuery(this).dialog('close');
                }
              }
            });
            e.preventDefault();
            jQuery.ajax({
              type: 'GET',
              url: jQuery.rootPath() + 'questions/new',
              data: {'question[question_instance_id]': questionInstanceId, 'question[parent_id]': questionId},
              beforeSend: function(){
                jQuery('#spinner_block').show();
              },
              success: function(html){
                jQuery('#spinner_block').hide();
                jQuery('#new-question-form').html(html);
                jQuery('#new-question-form').dialog('open');
              }
            });
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
            jQuery.observeNewQuestionControl();
            jQuery.observeShowReplyControls();
            jQuery('div.updated').stop().css("background-color", "#FFFF9C").animate({ backgroundColor: "#FFFFFF"}, 2000);
          }
        });
      }
  });

    jQuery(document).ready(function(){
      jQuery.observeVoteControls();
      jQuery.observeNewQuestionControl();
      jQuery.observeShowReplyControls();
  });
});
