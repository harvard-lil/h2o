/* goo-goo gajoob */
jQuery(function(){
    jQuery.extend({
      showReplyContainer: function(questionInstanceId,questionId,repliesContainer,toggleSpeed,isOwner){
        /* figures out if a question has its replies shown - if it does, it does an Ajax request to get the list
           of replies and then toggles the reply container on the question. 
         */
        jQuery.ajax({
          type: 'GET',
          url: jQuery.rootPath() + 'questions/replies/' + questionId,
          beforeSend: function(){jQuery('#spinner_block').show()},
          success: function(html){
            jQuery('#spinner_block').hide();
            repliesContainer.html(html).toggle(toggleSpeed);
            //We only want to observe the new replies.
            jQuery.observeQuestionControl(jQuery('#replies-for-question-' + questionId), questionInstanceId, questionId,isOwner);
            jQuery.convertTime(jQuery('#replies-for-question-' + questionId),UTC_OFFSET);
            jQuery('#show-replies-on-' + questionId).button({label: 'hide'});
          },
          error: function(xhr){
            jQuery('#spinner_block').hide();
            jQuery('div.ajax-error').show().append(xhr.responseText);
          }
        });
      },
      removeReplyContainerFromCookie: function(cookieName,replyContainer){
        /* self documenting - removes a reply container from the tracking cookie. Spawned when a reply container is
           closed. 
         */
        var currentVals = jQuery.unserializeHash(jQuery.cookie(cookieName));
        delete currentVals[replyContainer];
        var cookieVal = jQuery.serializeHash(currentVals);
        jQuery.cookie(cookieName,cookieVal);
      },
      addReplyContainerToCookie: function(cookieName,replyContainer){
        /* See above. Adds a reply container id to the cookie. Spawned when a reply container is shown. 
         */
        var currentVals = jQuery.unserializeHash(jQuery.cookie(cookieName));
        currentVals[replyContainer] = 1;
        var cookieVal = jQuery.serializeHash(currentVals);
        jQuery.cookie(cookieName,cookieVal);
      },
      observeQuestionControl: function(element,questionInstanceId,questionId,isOwner){
        /* Sets up the new question jQuery.dialog() and then populates the form via an ajax call. It then shows
           the dialog containing the form.
           It also determines if the user is the owner and lights up remove/sticky controls.
         */
        if(isOwner){
          jQuery(element).find('.meta .destroy').append('<img src="/images/icons/cancel.png" alt="Delete this item" />');
          jQuery(element).find('.meta .toggle-sticky').append('<img src="/images/icons/tick_gray.png" alt="Toggle Stickiness" />');

          jQuery(element).find('.meta .destroy').click(function(e){
            var interiorQuestionId = jQuery(this).attr('id').split('-')[1];
            e.preventDefault();
            if(confirm('Are you sure?')){
              jQuery.ajax({
              type: 'POST',
                data: {'_method': 'delete'},
                url: jQuery.rootPath() + "questions/destroy/" + interiorQuestionId,
                beforeSend: function(){
                  jQuery('#spinner_block').show();
                },
                success: function(html){
                  jQuery('#spinner_block').hide();
                  jQuery.updateQuestionInstanceView(questionInstanceId);
                },
                error: function(xhr){
                  jQuery('div.ajax-error').show().append(xhr.responseText);
                },
              });
            }
          });
          jQuery(element).find('.meta .toggle-sticky').click(function(e){
            var interiorQuestionId = jQuery(this).attr('id').split('-')[2];
            e.preventDefault();
            jQuery.ajax({
              type: 'POST',
              url: jQuery.rootPath() + "questions/toggle_sticky/" + questionId,
              success: function(html){
                jQuery.updateQuestionInstanceView(questionInstanceId)
              },
              error: function(xhr){
                jQuery('div.ajax-error').show().append(xhr.responseText);
              },
            });
          });
        }

        jQuery(element).find('a.new-question-for').button({icons: {primary: 'ui-icon-circle-plus'}}).click(function(e){
          if(jQuery('#logged-in').length > 0){
            e.preventDefault();
            var interiorQuestionId = jQuery(this).attr('id').split('-')[4];
            var submitQuestionForm = function(){jQuery('#new-question-form form').ajaxSubmit({
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
                      //TODO - resolve the "parent" question id and return it in response text.
                      jQuery.updateQuestionInstanceView(questionInstanceId)
                      jQuery('#new-question-form').dialog('close');
                    }
                  });
            };
            var dialogTitle = 'Add to the discussion';
            jQuery('#new-question-form').dialog({
              bgiframe: true,
              autoOpen: false,
              minWidth: 300,
              width: 450,
              modal: true,
              title: dialogTitle,
              buttons: {
                'Save': submitQuestionForm,
                'Cancel': function(){
                  jQuery('#new-question-error').html('').hide();
                  jQuery(this).dialog('close');
                }
              }
            });
            jQuery.ajax({
              type: 'GET',
              url: jQuery.rootPath() + 'questions/new',
              data: {'question[question_instance_id]': questionInstanceId, 'question[parent_id]': interiorQuestionId},
              beforeSend: function(){
                jQuery('#spinner_block').show();
              },
              success: function(html){
                jQuery('#spinner_block').hide();
                jQuery('#new-question-form').html(html);
                jQuery('#new-question-form').dialog('open');
              }
            });
          }
        });
      },
      toggleVoteControls: function(){
        /* Do an ajax request to get the votes this user has submitted. Kick ass-feature (if you get the reference,
           you win a cookie).
           This  allows us to cache on the question-question-instance level, instead of on the
           question-question-instance-user level, which would be no kind of caching at all. 
         */
        jQuery.ajax({
          type: 'GET',
          url: jQuery.rootPath() + 'users/has_voted_for/Question',
          error: function(xhr){
            jQuery('div.ajax-error').show().append(xhr.responseText);
          },
          success: function(html){
            var votes = html;
            for(i in votes){
              jQuery("#votes-for-" + i + ' a').addClass('already-voted');
            }
          }
        });
      },

      observeVoteControls: function(element,questionInstanceId,questionId) {
        /* Inits the up/down arrows, ignoring those with an "already-voted" class, which is applied earlier
         */
        jQuery(element).find("a[id*='vote-']").click(function(e){
          e.preventDefault();
          var for_or_against = jQuery(this).attr('id').split('-')[1];
          if(jQuery(this).hasClass('already-voted')){
            return;
          }
          var dispatch_url = (for_or_against == 'for') ? jQuery.rootPath() + 'questions/vote_for' : jQuery.rootPath() + 'questions/vote_against';
          jQuery.ajax({
            type: 'POST',
            url: dispatch_url,
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
              jQuery.updateQuestionInstanceView(questionInstanceId);
            }
          });
        });
      },
      updateQuestionInstanceView: function(questionInstanceId,updatedSince){
        /* Update the question instance view - most likely because a question/reply has been added or a vote has been cast. 
         */
        if(! updatedSince || updatedSince.length == 0){
          updatedSince = jQuery('#updated-at').html();
        }
        jQuery.ajax({
          type: 'GET',
          url: jQuery.rootPath() + 'question_instances/' + questionInstanceId,
          data: {sort: jQuery.cookie('sort')},
          error: function(xhr){
            jQuery('div.ajax-error').show().append(xhr.responseText);
          },
          success: function(html){
            jQuery('#questions-' + questionInstanceId).html(html); 
            jQuery.observeQuestionCollection();
            jQuery.ajax({
              type: 'GET',
              url: jQuery.rootPath() + 'question_instances/last_updated_questions/' + questionInstanceId,
              data: {time: updatedSince},
              success: function(innerHtml){
                if(innerHtml.length > 0){
                  jQuery(innerHtml).each(function(){
                    jQuery('#question-' + this).effect('pulsate');
                  });
                }
              },
              error: function(xhr){
              }
            });
          }
        });
      },
/*      observeUpdateTimers: function(){
       jQuery('#timer-controls a').click(function(e){
           e.preventDefault();
           var timerSeconds = jQuery(this).attr('id').split('-')[1];
           jQuery('#timer-controls a.selected').removeClass('selected');
           jQuery(this).addClass('selected');
           alert(jQuery('#updated-at').attr('class'));
           clearInterval(jQuery('#updated-at').attr('class'));
           jQuery('#updated-at').attr('class',setInterval("jQuery.updateAutomatically()", timerSeconds * 1000));
           jQuery('#timer-notice').html('updated!').delay(2000).html('');
       }); 
      },
*/
      updateAutomatically: function(){
        /* Poll to see if the server thinks something in this question instance has changed. If it has, update
           the question instance view. 
         */
        var lastUpdated = jQuery('#updated-at').html();
        var currentlyPolling = jQuery('#updated-at-singleton').html();
        if (currentlyPolling != 'true'){
          var questionInstanceId = jQuery('div.questions').attr('id').split('-')[1];
          jQuery.ajax({
            type: 'GET',
            url: jQuery.rootPath() + 'question_instances/updated/' + questionInstanceId,
            beforeSend: function(){
              jQuery('#spinner_block').show();
              jQuery('#updated-at-singleton').html('true');
            },
            success: function(html){
              if(lastUpdated != html){
                jQuery.updateQuestionInstanceView(questionInstanceId,lastUpdated);
              }
            },
            error: function(xhr){
              jQuery('div.ajax-error').show().append(xhr.responseText);
            },
            complete: function(){
              jQuery('#spinner_block').hide();
              jQuery('#updated-at-singleton').html('');
            }
          });
        }
      },
      observeQuestionInstanceControl: function(){
        /* Observe parts of the question instance list. Set up the edit / new jQuery.dialog(), 
           set up the dispatch URL and then update / reobserve upon successful submission.
        */
        jQuery('a.question-instance-control').click(function(e){
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
/*                        jQuery('#spinner_block').hide();
                        jQuery('#question-instance-list').html(html);
                        jQuery("#question-instance-chooser").tablesorter();
                        jQuery.observeQuestionInstanceControl(); 
                        Doesn't work properly.
 */
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
        });
      },
      observeShowReplyControls: function(element,questionInstanceId,questionId,openReplyContainers,isOwner){
        /* Observe the link that toggles whether or not a reply is shown. invoke the add/remove reply container
           from cookie methods and spawn and ajax update to show the replies.
         */
        var repliesContainer = jQuery('#replies-container-' + questionId);
        jQuery(element).find('a.show-replies').button({icons: {primary: 'ui-icon-carat-2-n-s'}}).click(function(e){
          e.preventDefault();
          if(repliesContainer.html().length > 0 && repliesContainer.is(':visible')){
            //There's content in here and it's visible. Just hide it.
            repliesContainer.toggle('fast');
            jQuery.removeReplyContainerFromCookie('show-reply-containers','#replies-container-' + questionId);
            jQuery(this).button({label: 'show'});
          } else {
            //There's no content, or there's content and it's invisible. 
            //Get the replies again to ensure fresh content.
            jQuery.addReplyContainerToCookie('show-reply-containers','#replies-container-' + questionId);
            jQuery.showReplyContainer(questionInstanceId,questionId,repliesContainer,'fast',isOwner);
          }
        });
        if(openReplyContainers['#replies-container-' + questionId] == 1){
          jQuery.showReplyContainer(questionInstanceId,questionId,repliesContainer,0,isOwner);
        }
      },
      convertTime: function(element,offset){
        jQuery(element).find('.unixtime').each(function(){
          var unixtime = jQuery(this).html();
          var qDate = new Date();
          var localDate = new Date(((unixtime * 1000) + offset) + (qDate.getTimezoneOffset() * 60000) );
          jQuery(this).html(localDate.getHours() + ':' + (localDate.getMinutes() < 10 ? '0' : '') + localDate.getMinutes() + ' ' + (localDate.getMonth() + 1) + '/' + localDate.getDate() + '/' + localDate.getFullYear());
        });
      },
      observeSortControl: function(questionInstanceId){
        jQuery('#sort').each(function(){
            if(jQuery.cookie('sort') && jQuery.cookie('sort') != jQuery(this).val()){
              jQuery(this).val(jQuery.cookie('sort')); 
            }
            jQuery(this).change(function(){
              jQuery.cookie('sort', jQuery(this).val());
              jQuery.updateQuestionInstanceView(questionInstanceId);
            });
        });
      },
      determineOwnershipAndInit: function(){
        var questionInstanceId = jQuery('div.questions').attr('id').split('-')[1];
        var isOwner = false;
        if(jQuery('#is-owner').html() == 'true'){
          isOwner = true;
        }
        jQuery.observeQuestionControl(jQuery('#controls-' + questionInstanceId),questionInstanceId,0,isOwner);
        jQuery.observeSortControl(questionInstanceId);
        jQuery.observeQuestionCollection();
      },
      observeQuestionCollection: function(){
        /* So this figures out the question instance we're in, de-activates the already used vote controls,
           finds the questions that need to be observed and then dispatches to other jQuery methods
           to figure out which questions have their replies show and to observe the controls on each. We're doing it
           it one loop (with .find() restricted sub-loops for each jQuery.observe* method) and this seems to be
           faster than looping through the DOM for each control - unsurprisingly. */
        var questionInstanceId = jQuery('div.questions').attr('id').split('-')[1];
        var isOwner = (jQuery('#is-owner').html() == 'true') ? true : false;
        jQuery.toggleVoteControls();
        jQuery("div[id*='question-']").each(function(){
          var questionId = jQuery(this).attr('id').split('-')[1];
          var openReplyContainers = jQuery.unserializeHash(jQuery.cookie('show-reply-containers'));
          if(jQuery(this).hasClass('question')){
          // It's a question. Init the reply toggles and voting
            jQuery.observeShowReplyControls(this,questionInstanceId,questionId,openReplyContainers,isOwner);
            jQuery.observeVoteControls(this,questionInstanceId,questionId);
          }
          jQuery.observeQuestionControl(this,questionInstanceId,questionId,isOwner);
          jQuery.convertTime(this,UTC_OFFSET);
        });
      }

  });

    jQuery(document).ready(function(){
      if(jQuery(".question-instance-control").length > 0){
        // We're on the question instance list page.
        jQuery.observeQuestionInstanceControl();
        if(jQuery('#question-instance-chooser').length > 0){
          jQuery("#question-instance-chooser").tablesorter();
        }
      } else {
        // We're viewing a question instance.
        jQuery.determineOwnershipAndInit();
//        jQuery.observeUpdateTimers();
        setInterval("jQuery.updateAutomatically()",10000);
//        jQuery('#timer-controls #seconds-5').addClass('selected');
      }
  });
});
