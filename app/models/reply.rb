class Reply < ActiveRecord::Base
  acts_as_voteable
  acts_as_category :scope => :question
  attr_accessible :reply, :email, :name, :posted_anonymously
  belongs_to :question
  belongs_to :user

  validates_presence_of :question_id, :reply
  validates_length_of :reply, :maximum => 1000
  validates_length_of :email, :name,
    :maximum => 250, :allow_nil => true

  validates_format_of_email :email, :allow_nil => true

  validates_numericality_of :parent_id, :children_count, :ancestors_count, :descendants_count, :position, :allow_nil => true

end
