/* goo-goo gajoob */

jQuery(function(){

    jQuery.extend({
      observeNewQuestionControl: function(){
        jQuery('a.new-question-for').click(function(){
          var questionInstanceId = jQuery(this).attr('id').split('-')[3];
          jQuery('#new-question-form-for-' + questionInstanceId).dialog('open');
        });
      },
      observeNewQuestion: function(){
        jQuery('div.new-question-form').dialog({
          bgiframe: true,
          autoOpen: false,
          minwidth: 300,
          modal: true,
          buttons: {
            'Ask Question': function(){
            alert('you asked a question!');
            }
            }
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
          url: jQuery.rootPath() + 'question_instances/' + questionInstanceId,
          data: {updated_question_id: questionId},
          success: function(html){jQuery('#questions-' + questionInstanceId).html(html); jQuery.observeVoteControls();}
        });
      }
    });

    jQuery(document).ready(function(){
      jQuery.observeVoteControls();
      jQuery.observeNewQuestionControl();
      jQuery.observeNewQuestion();
    });

});
