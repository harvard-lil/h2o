class QuestionInstance < ActiveRecord::Base
  belongs_to :project
  belongs_to :user
  has_many :questions
  has_many :replies, :through => :questions
  acts_as_category :scope => :project

  validates_presence_of :name
  validates_length_of :name, :in => 1..250
  validates_length_of :password, :maximum => 128, :allow_nil => true
  validates_length_of :description, :maximum => 2000, :allow_nil => true

end
