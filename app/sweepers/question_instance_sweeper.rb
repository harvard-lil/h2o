require 'sweeper_helper'
class QuestionInstanceSweeper < ActionController::Caching::Sweeper
  include SweeperHelper

  observe QuestionInstance

  def after_save(record)
    expire_fragment('question-instance-list')
  end

  def before_destroy(record)
    expire_fragment('question-instance-list')
  end

end
