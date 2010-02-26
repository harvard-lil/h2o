/* goo-goo gajoob */

jQuery(function(){

    jQuery.extend({
      observeVoteControls: function() {
        jQuery("a[id*='vote-for']").click(function(){
          var questionInstanceId = jQuery(this).attr('id').split('-')[2];
          var questionId = jQuery(this).attr('id').split('-')[3];
          jQuery.ajax({
            type: 'POST',
            url: jQuery.rootPath() + 'questions/vote_for',
            data: {question_id: questionId, authenticity_token: AUTH_TOKEN},
            beforeSend: function(){jQuery('#ajax-error').html('').hide()},
            error: function(xhr){jQuery('#ajax-error').show().append(xhr.responseText);}
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
    });

});
