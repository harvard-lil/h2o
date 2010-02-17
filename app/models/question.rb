class Question < ActiveRecord::Base
  acts_as_voteable
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

  def self.featured(question_instance)
    #Unsure how this could efficiently be expressed within a named scope, especially since it's an aggregate function.
    self.find_by_sql(["select questions.id,count(votes.id) 
                     from questions 
                     left outer join votes on (questions.id = votes.voteable_id and votes.voteable_type = ? and votes.vote is true) 
                     where 
                     questions.question_instance_id = ? 
                     group by questions.id 
                     order by count(votes.id) limit ?", 
                     self.name, 
                     question_instance.id,
                     question_instance.featured_question_count
    ])
  end

end
