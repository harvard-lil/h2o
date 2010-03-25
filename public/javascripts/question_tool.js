/* goo-goo gajoob */
jQuery(function(){
    jQuery.extend({
      showReplyContainer: function(questionId,repliesContainer,toggleSpeed){
        jQuery.ajax({
          type: 'GET',
          url: jQuery.rootPath() + 'questions/replies/' + questionId,
          beforeSend: function(){jQuery('#spinner_block').show()},
          success: function(html){
            jQuery('#spinner_block').hide();
            repliesContainer.html(html).toggle(toggleSpeed);
            //We only want to observe the new replies, so set a root selector to ensure we aren't double-observing.
            jQuery.observeNewQuestionControl('#replies-for-question-' + questionId);
          },
          error: function(xhr){
            jQuery('#spinner_block').hide();
            jQuery('div.ajax-error').show().append(xhr.responseText);
          }
        });
      },
      serializeHash: function(hashVals){
        var vals = [];
        for(var val in hashVals){
          if(val != undefined){
            vals.push(val);
          }
        }
        return vals.join(',');
      },
      unserializeHash: function(stringVal){
        if(stringVal && stringVal != undefined){
          var hashVals = [];
          var arrayVals = stringVal.split(',');
          for(var i in arrayVals){
            hashVals[arrayVals[i]]=1;
          }
          return hashVals;
        } else {
          return new Array();
        }
      },
      removeReplyContainerFromCookie: function(cookieName,replyContainer){
        var currentVals = jQuery.unserializeHash(jQuery.cookie(cookieName));
        delete currentVals[replyContainer];
        var cookieVal = jQuery.serializeHash(currentVals);
        jQuery.cookie(cookieName,cookieVal);
      },
      addReplyContainerToCookie: function(cookieName,replyContainer){
        var currentVals = jQuery.unserializeHash(jQuery.cookie(cookieName));
        currentVals[replyContainer] = 1;
        var cookieVal = jQuery.serializeHash(currentVals);
        jQuery.cookie(cookieName,cookieVal);
      },
      observeShowReplyControls: function(){
        jQuery('a.show-replies').each(function(){
          var questionId = jQuery(this).attr('id').split('-')[3];
          var repliesContainer = jQuery('#replies-container-' + questionId);
          var openReplyContainers = jQuery.unserializeHash(jQuery.cookie('show-reply-containers'));
          jQuery(this).click(function(e){
            e.preventDefault();
            if(repliesContainer.html().length > 0 && repliesContainer.is(':visible')){
              //There's content in here and it's visible. Just hide it.
              repliesContainer.toggle('fast');
              jQuery.removeReplyContainerFromCookie('show-reply-containers','#replies-container-' + questionId);
            } else {
              //There's no content, or there's content and it's invisible. 
              //Get the replies again to ensure fresh content.
              jQuery.addReplyContainerToCookie('show-reply-containers','#replies-container-' + questionId);
              jQuery.showReplyContainer(questionId,repliesContainer,'fast');
            }
          });
          if(openReplyContainers['#replies-container-' + questionId] == 1){
            jQuery.showReplyContainer(questionId,repliesContainer,0);
          }
        });
      },
      observeNewQuestionControl: function(rootSelector){
        jQuery(((rootSelector) ? rootSelector + ' ' : '') + 'a.new-question-for').each(function(){
          jQuery(this).click(function(e){
            var questionInstanceId = jQuery(this).attr('id').split('-')[3];
            var questionId = jQuery(this).attr('id').split('-')[4];
            var dialogTitle = 'Add to the discussion';
            jQuery('#new-question-form').dialog({
              bgiframe: true,
              autoOpen: false,
              minWidth: 300,
              width: 450,
              modal: true,
              title: dialogTitle,
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
        jQuery("a[id*='vote-for']").click(function(e){
          e.preventDefault();
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
      if(jQuery("#question-instance-chooser").length > 0){
        jQuery("#question-instance-chooser").tablesorter();
      }
  });
});
