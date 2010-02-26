/* goo-goo gajoob */

jQuery(function(){

    jQuery.extend({
      observeVoteControls: function() {
        jQuery("a[id*='vote-for']").click(function(){
          var questionId = jQuery(this).attr('id').split('-')[2];
          var questionInstanceId = jQuery(this).attr('id').split('-')[3];
          jQuery.ajax({
            type: 'POST',
            url: jQuery.rootPath() + 'questions/vote_for',
            data: {question_id: questionId, authenticity_token: AUTH_TOKEN},
            success: jQuery.updateQuestionInstanceView(questionInstanceId,questionId),
           // failure: jQuery('#ajax-error').show()
          });
          return false;
          });
        },
      updateQuestionInstanceView: function(questionInstanceId,questionId){
        jQuery.ajax({
          type: 'GET',
          url: jQuery.rootPath() + 'question_instances/' + questionInstanceId,
          data: {updated_question_id: questionId}
          //,
          /success: jQuery('#questions').html


          });
      }
    });

    jQuery(document).ready(function(){
      jQuery.observeVoteControls();
      });

    });
