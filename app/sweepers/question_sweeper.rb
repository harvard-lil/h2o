require 'sweeper_helper'
class QuestionSweeper < ActionController::Caching::Sweeper
  include SweeperHelper

  observe Question

  def after_save(record)
    logger.warn('Expiring!')
    expire_question(record)
    expire_question_instance(record)
  end

end
