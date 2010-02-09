class QuestionInstancesController < BaseController
  before_filter :prep_resources


  def index

  end

  private

  def prep_resources
    add_stylesheets 'question_tool'
  end

end
