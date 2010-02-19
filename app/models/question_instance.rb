class QuestionInstance < ActiveRecord::Base
  FEATURED_QUESTION_COUNTS = [[2,2],[4,4],[6,6],[8,8],[10,10]]
  NEW_QUESTION_TIMEOUTS = [['30 seconds',30],['1 minute',60],['5 minutes',300],['1 hour',3600],['1 day',86400],['1 week',604800]]
  OLD_QUESTION_TIMEOUTS = [['15 minutes',900],['30 minutes',1800],['1 hour',3600],['1 day',86400],['1 week',604800],['30 days',86400 * 30],[ '1 year',86400 * 36,]]

#  belongs_to :project
  belongs_to :user
  has_many :questions
  has_many :replies, :through => :questions
  acts_as_category :scope => :project

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_length_of :name, :in => 1..250
  validates_length_of :password, :maximum => 128, :allow_nil => true
  validates_length_of :description, :maximum => 2000, :allow_nil => true

  validates_inclusion_of :featured_question_count, :in => FEATURED_QUESTION_COUNTS.collect{|c| c[1]}, :allow_blank => true
  validates_inclusion_of :new_question_timeout, :in => NEW_QUESTION_TIMEOUTS.collect{|c| c[1]}, :allow_blank => true
  validates_inclusion_of :old_question_timeout, :in => OLD_QUESTION_TIMEOUTS.collect{|c| c[1]}, :allow_blank => true

  validates_numericality_of :parent_id, :children_count, :ancestors_count, :descendants_count, :position, :new_question_timeout, :featured_question_count, :old_question_timeout, :allow_nil => true

  def featured_questions(params = {})
    Question.featured(params.merge(:question_instance => self))
  end

  def not_featured_questions(params = {})
    Question.not_featured(params.merge(:question_instance => self))
  end

end
