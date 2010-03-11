class Question < ActiveRecord::Base
  acts_as_voteable
  acts_as_category :scope => :question_instance
  attr_accessible :question_instance_id, :question, :email, :name, :posted_anonymously
  belongs_to :question_instance
  belongs_to :user

  validates_presence_of :user_id, :question, :question_instance_id
  validates_length_of :question, 
    :maximum => 10000

  validates_length_of :email, :name, 
    :maximum => 250, :allow_nil => true

  validates_format_of_email :email, :allow_nil => true

  validates_numericality_of :parent_id, :children_count, :ancestors_count, :descendants_count, :position, :allow_nil => true

  def self.featured(params)
    logger.warn(params.inspect)
    #Unsure how this could efficiently be expressed within a named scope, especially since it's an aggregate function.
    #We're essentially forcing eager loading for the question object here.
    columns = self.columns.collect{|c| "questions.#{c.name}"}.join(',')

    fq = self.find_by_sql(["select #{columns} ,count(votes.id) as vote_count
                     from questions 
                     left outer join votes on (questions.id = votes.voteable_id and votes.voteable_type = ? and votes.vote is true) 
                     where 
                     questions.question_instance_id = ? 
                     group by #{columns} 
                     order by sticky desc,vote_count desc, questions.id desc limit ?", 
                     self.name, 
                     params[:question_instance].id,
                     params[:question_instance].featured_question_count
    ])
  end

  def self.not_featured(params)
    #Unsure how this could efficiently be expressed within a named scope, especially since it's an aggregate function.
    #We're essentially forcing eager loading for the question object here.

    questions_to_exclude = []
    if params[:questions_to_exclude].blank?
      params[:questions_to_exclude] = self.featured(params)
    end

    questions_to_exclude = params[:questions_to_exclude].collect{|q|q.id}.join(',')

    columns = self.columns.collect{|c| "questions.#{c.name}"}.join(',')

    fq = self.find_by_sql(["select #{columns} ,count(votes.id) as vote_count
                     from questions 
                     left outer join votes on (questions.id = votes.voteable_id and votes.voteable_type = ? and votes.vote is true) 
                     where 
                     questions.question_instance_id = ?
                     and questions.id not in(#{questions_to_exclude})
                     group by #{columns} 
                     order by sticky desc,vote_count desc, questions.id desc", 
                     self.name, 
                     params[:question_instance].id
    ])
  end

  def reply_count
    reply_count_val = self.children.length
    (reply_count_val == 0) ? 'no replies' : ((reply_count_val == 1) ? '1 reply' : "#{reply_count_val} replies")
  end

end
