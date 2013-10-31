class RotisseriePost < ActiveRecord::Base
  include RotisserieUtilities
  
  acts_as_authorization_object
  acts_as_category :scope => :rotisserie_discussion

  validates_presence_of :title
  validates_uniqueness_of :title, :scope => :rotisserie_discussion_id

  belongs_to :rotisserie_discussion
  belongs_to :user
  has_many :rotisserie_assignments
  has_many :rotisserie_trackers

  def current_user
    session = UserSession.find
    current_user = session && session.user
    return current_user
  end

  def assigned?
    return RotisserieAssignment.exists?({:rotisserie_discussion_id => self.rotisserie_discussion.id, :rotisserie_post_id => self.id, :round => self.rotisserie_discussion.current_round, :user_id => current_user.id})
  end

  def answered_by_user?
    posts = self.children
    posts.each do |post|
      if post.author == current_user then return true end
    end

    return false
  end

  def editable?
    return (self.author? && !self.initial_round_completed? && self.rotisserie_discussion.open?) || self.rotisserie_discussion.author?
  end

  def display?
    return (self.round < self.rotisserie_discussion.current_round) || (self.round > self.rotisserie_discussion.final_round) || self.rotisserie_discussion.author?
  end

  def replyable?
    #return self.discussion.open? && !self.author?(current_user)
    return self.rotisserie_discussion.author? || (self.assigned? && !self.answered_by_user?)
  end

  def viewable?
    return (self.author == current_user) || self.display?
  end

  def initial_round_completed?
    return self.rotisserie_discussion.current_round > self.round
  end

#  def send_notify
#    NotifyPublisher.deliver_notify(self)
#
#    rescue Facebooker::Session::SessionExpired
#    # We can't recover from this error, but
#    # we don't want to show an error to our user
#  end

end
