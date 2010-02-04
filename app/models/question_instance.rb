class QuestionInstance < ActiveRecord::Base
  FEATURED_QUESTION_COUNTS = [[2,2],[4,4],[6,6],[8,8],[10,10]]
  NEW_QUESTION_TIMEOUTS = [[30,'30 seconds'],[60,'1 minute'],[300,'5 minutes'],[3600,'1 hour'],[86400,'1 day'],[604800,'1 week']]
  OLD_QUESTION_TIMEOUTS = [[900,'15 minutes'],[1800,'30 minutes'],[3600,'1 hour'],[86400,'1 day'],[604800,'1 week'],[86400 * 30, '30 days'],[86400 * 365, '1 year']]

  belongs_to :project
  belongs_to :user
  has_many :questions
  has_many :replies, :through => :questions
  acts_as_category :scope => :project

  validates_presence_of :name
  validates_length_of :name, :in => 1..250
  validates_length_of :password, :maximum => 128, :allow_nil => true
  validates_length_of :description, :maximum => 2000, :allow_nil => true

  validates_length_of :email, :name, 
    :maximum => 250, :allow_nil => true

  validates_format_of_email :email, :allow_nil => true
  validates_numericality_of :new_question_timeout, :featured_question_count, :old_question_timeout, :allow_nil => true
end
