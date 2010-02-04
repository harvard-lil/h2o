class Question < ActiveRecord::Base
  belongs_to :question_instance
  belongs_to :user

  validates_presence_of :question

  validates_length_of :question, 
    :maximum => 10000

  validates_length_of :email, :name, 
    :maximum => 250, :allow_nil => true

  validates_format_of_email :email, :allow_nil => true


end
