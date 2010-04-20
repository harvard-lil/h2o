require 'sweeper_helper'
class QuestionInstanceSweeper < ActionController::Caching::Sweeper
  include SweeperHelper

  observe QuestionInstance

  def after_save(record)
    expire_question_instance(record)
  end

  def before_destroy(record)
    expire_question_instance(record)
  end

end
