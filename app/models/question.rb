require 'redcloth_extensions'

class Question < ActiveRecord::Base
  extend RedclothExtensions::ClassMethods
  include AuthUtilities
  include Authorship

  acts_as_authorization_object

  POSSIBLE_SORTS = {
    :sticky_votes_id => {
      :display_sort_order => 1,
      :name => 'Votes',
      :function => lambda{|a,b|
        [sprintf('%015d', (b.sticky) ? 1 : 0), sprintf('%015d',b.vote_tally), sprintf('%015d',b.id)].join('') <=> [sprintf('%015d', (a.sticky) ? 1 : 0), sprintf('%015d',a.vote_tally), sprintf('%015d',a.id)].join('')
      },
    },
    :sticky_votes_id_asc => {
      :display_sort_order => 2,
      :name => 'Votes reverse',
      :function => lambda{|a,b|
        [sprintf('%015d', (a.sticky) ? 0 : 1), sprintf('%015d',a.vote_tally), sprintf('%015d',a.id)].join('') <=> [sprintf('%015d', (b.sticky) ? 0 : 1), sprintf('%015d',b.vote_tally), sprintf('%015d',b.id)].join('')
      },
    },
    :newest => {
      :display_sort_order => 3,
      :name => 'Newest',
      :function => lambda{|a,b|
        [sprintf('%015d', (b.sticky) ? 1 : 0), sprintf('%015d',b.created_at.to_i), sprintf('%015d',b.id)].join('') <=> [sprintf('%015d', (a.sticky) ? 1 : 0), sprintf('%015d',a.created_at.to_i), sprintf('%015d',a.id)].join('')
      }
    },
    :oldest => {
      :display_sort_order => 4,
      :name => 'Oldest',
      :function => lambda{|a,b|
        [sprintf('%015d', (a.sticky) ? 0 : 1), sprintf('%015d',a.created_at.to_i), sprintf('%015d',a.id)].join('') <=> [sprintf('%015d', (b.sticky) ? 0 : 1), sprintf('%015d',b.created_at.to_i), sprintf('%015d',b.id)].join('')
      }
    },
    :most_active => {
      :display_sort_order => 5,
      :name => 'Most Active',
      :function => lambda{|a,b|
        [sprintf('%015d', (b.sticky) ? 1 : 0), sprintf('%015d',b.votes.length + b.descendants.length), sprintf('%015d',b.id)].join('') <=> [sprintf('%015d', (a.sticky) ? 1 : 0), sprintf('%015d',a.votes.length + a.descendants.length), sprintf('%015d',a.id)].join('')
      },
    },
    :least_active => {
      :display_sort_order => 6,
      :name => 'Least Active',
      :function => lambda{|a,b|
        [sprintf('%015d', (a.sticky) ? 0 : 1), sprintf('%015d',a.votes.length + a.descendants.length), sprintf('%015d',a.id)].join('') <=> [sprintf('%015d', (b.sticky) ? 0 : 1), sprintf('%015d',b.votes.length + b.descendants.length), sprintf('%015d',b.id)].join('')
      }
    }
  }

  POSSIBLE_SORTS_FOR_SELECT = POSSIBLE_SORTS.keys.sort{|a,b|POSSIBLE_SORTS[a][:display_sort_order] <=> POSSIBLE_SORTS[b][:display_sort_order]}.collect{|s| [POSSIBLE_SORTS[s][:name],s]}

  acts_as_voteable
  acts_as_category :scope => :question_instance
  attr_accessible :question_instance_id, :question, :parent_id
  belongs_to :question_instance
  belongs_to :user

  after_save :update_root_question
  after_destroy :update_root_question

  validates_presence_of :user_id, :question, :question_instance_id
  validates_length_of :question,
    :maximum => 10000

  validates_numericality_of :parent_id, :children_count, :ancestors_count, :descendants_count, :position, :allow_nil => true

  searchable do
    text :display_name
    string :display_name, :stored => true
    string :id, :stored => true
    text :question
    string :question, :stored => true
  end

  def reply_list
    self.children.find(:all, :order => 'position')
  end

  def display_datetime
    (self.created_at > 1.day.ago) ? self.created_at.to_s(:simpletime) : self.created_at.to_s(:simpledatetime)
  end

  def self.featured(params)
    fq = self.find(:all, :include => ['votes'], :conditions => ["question_instance_id = ? and parent_id is null", params[:question_instance].id])

    # Be sure the sort method is one of the configured ones.
    sort_method = (params[:sort].nil? || POSSIBLE_SORTS[params[:sort].to_sym].blank?) ? :sticky_votes_id : params[:sort].to_sym
    sorted_fq = fq.sort do |a,b|
      POSSIBLE_SORTS[sort_method][:function].call(a,b)
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

    q = self.find(:all, :include => ['votes'], :conditions => ["question_instance_id = ? #{extra_conditions} and parent_id is null", params[:question_instance].id])
    # Be sure the sort method is one of the configured ones.
    sort_method = (params[:sort].nil? || POSSIBLE_SORTS[params[:sort].to_sym].blank?) ? :sticky_votes_id : params[:sort].to_sym
    sorted_q = q.sort do |a,b|
      POSSIBLE_SORTS[sort_method][:function].call(a,b)
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
    (reply_count_val == 0) ? 'no comments' : ((reply_count_val == 1) ? '1 comment' : "#{reply_count_val} comments")
  end

  def display_name
    owners = self.accepted_roles.find_by_name('owner')
    "\"#{self.question[0..80]}...\",  #{self.created_at.to_s(:simpledatetime)} #{(owners.blank?) ? '' : ' by ' + owners.users.collect{|u| u.login}.join(',')}"
  end

  def tags
	[]
  end

  private

  def update_root_question
    if self.parent_id != nil
      root_question = self.ancestors.last
      root_question.updated_at = Time.now
      root_question.save
    end
  end
end
