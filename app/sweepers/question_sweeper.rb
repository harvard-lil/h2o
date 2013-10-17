require 'sweeper_helper'
class QuestionSweeper < ActionController::Caching::Sweeper
  include SweeperHelper

  observe Question #, Vote

  def after_save(record)
    expire_question((record.is_a?(Question)) ? record : record.voteable)
    expire_question_instance((record.is_a?(Question)) ? record.question_instance : record.voteable.question_instance)
  end

  def before_destroy(record)
    expire_question((record.is_a?(Question)) ? record : record.voteable)
    expire_question_instance((record.is_a?(Question)) ? record.question_instance : record.voteable.question_instance)
  end

end
