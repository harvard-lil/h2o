class Question < ActiveRecord::Base
  include AuthUtilities

  acts_as_authorization_object

  acts_as_voteable
  acts_as_category :scope => :question_instance
  attr_accessible :question_instance_id, :question, :email, :name, :posted_anonymously, :parent_id
  belongs_to :question_instance
  belongs_to :user

  validates_presence_of :user_id, :question, :question_instance_id
  validates_length_of :question, 
    :maximum => 10000

  validates_length_of :email, :name, 
    :maximum => 250, :allow_blank => true

  validates_format_of_email :email, :allow_blank => true

  validates_numericality_of :parent_id, :children_count, :ancestors_count, :descendants_count, :position, :allow_nil => true

  def reply_list
    self.children.find(:all, :order => 'position desc')
  end

  def self.featured(params)
    #Unsure how this could efficiently be expressed within a named scope, especially since it's an aggregate function.
    #We're essentially forcing eager loading for the question object here.

    fq = self.find(:all, :include => ['votes'], :conditions => ["question_instance_id = ? and parent_id is null", params[:question_instance].id])

    sorted_fq = fq.sort do |a,b|
      #sort by sticky and then by vote count, desc.
      (b.sticky.to_s <=> a.sticky.to_s).nonzero? ||
        (b.vote_tally <=> a.vote_tally)
    end

    sorted_fq[0.. (params[:question_instance].featured_question_count - 1)]
  end

  def self.not_featured(params)

    questions_to_exclude = []
    if params[:questions_to_exclude].blank?
      params[:questions_to_exclude] = self.featured(params)
    end

    questions_to_exclude = params[:questions_to_exclude].collect{|q|q.id}.join(',')
    extra_conditions = ''
    if ! questions_to_exclude.blank?
      extra_conditions = " and id not in(#{questions_to_exclude}) "
    end

    q = self.find(:all,:conditions => ["question_instance_id = ? #{extra_conditions} and parent_id is null", params[:question_instance].id])
    sorted_q = q.sort do |a,b|
      #sort by sticky and then by vote count, desc.
      (b.sticky.to_s <=> a.sticky.to_s).nonzero? ||
        (b.vote_tally <=> a.vote_tally)
    end
    sorted_q
  end

  def vote_tally
    count = 0
    self.votes.each do |v|
      (v.vote) ? (count += 1) : (count -= 1)
    end
    count
  end

  def reply_count
    reply_count_val = self.children.length
    (reply_count_val == 0) ? 'no replies' : ((reply_count_val == 1) ? '1 reply' : "#{reply_count_val} replies")
  end

end
