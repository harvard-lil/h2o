class Question < ActiveRecord::Base
  acts_as_category :scope => :question_instance
  belongs_to :question_instance
  belongs_to :user
  has_many :replies, :order => :position

  validates_presence_of :user_id, :question, :question_instance_id
  validates_length_of :question, 
    :maximum => 10000

  validates_length_of :email, :name, 
    :maximum => 250, :allow_nil => true

  validates_format_of_email :email, :allow_nil => true

  validates_numericality_of :parent_id, :children_count, :ancestors_count, :descendants_count, :position, :allow_nil => true

end
