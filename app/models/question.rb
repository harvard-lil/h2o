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

  def self.featured(params)
    #Unsure how this could efficiently be expressed within a named scope, especially since it's an aggregate function.
    #We're essentially forcing eager loading for the question object here.
    columns = self.columns.collect{|c| "questions.#{c.name}"}.join(',')

    fq = self.find_by_sql(["select #{columns} ,count(votes.id) as vote_count
                     from questions 
                     left outer join votes on (questions.id = votes.voteable_id and votes.voteable_type = ? and votes.vote is true) 
                     where 
                     questions.question_instance_id = ? 
                     group by #{columns} 
                     order by sticky desc,vote_count desc limit ?", 
                     self.name, 
                     params[:question_instance].id,
                     params[:question_instance].featured_question_count
    ])
  end


end
