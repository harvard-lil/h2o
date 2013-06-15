class RotisserieDiscussion < ActiveRecord::Base

  include RotisserieUtilities
  include AuthUtilities
  include Authorship

  acts_as_authorization_object

  validates_presence_of :title
  validates_uniqueness_of :title, :scope => :rotisserie_instance_id

  belongs_to :rotisserie_instance
  has_many :rotisserie_posts
  has_many :rotisserie_assignments
  has_many :rotisserie_trackers
  has_many :roles, :as => :authorizable

  def output_text
    self.output
  end

  def user_assignments
    return self.rotisserie_assignments.all(:conditions => {:user_id => current_user.id})
  end

  def answered_discussion?
    posts = self.rotisserie_posts.find(:all, :conditions => {:ancestors_count => 0})
    posts.each do |post|
      return true if post.accepts_role?(:owner, current_user)
    end

    return false
  end

  ### Convert
  def get_last_round
    return self.rotisserie_posts.last.round
  end

  def get_last_assignment
    max_assignment_round = self.rotisserie_assignments.maximum('round').to_i
    if max_assignment_round.nil? then max_assignment_round = 0 end
    return max_assignment_round
  end

  def current_round
      date_to_round(self.start_date, Time.now(), self.round_length)
  end

  ### Convert
  def new_round?
      return current_round > get_last_round
  end

  def author?
    return role_users(self.id, self.class, "owner").first == current_user
  end

  def author
     role_users(self.id, self.class, "owner").first
  end

  def users
    role = Role.first(:conditions => {:authorizable_type => "RotisserieDiscussion", :authorizable_id => self.id, :name => "user"})

    return role.blank? ? Array.new : role.users
  end

  def get_round_startdate(round)
      return (self.start_date + (self.round_length * (round - 1)).days)
  end

  def get_round_enddate(round)
      return (get_round_startdate(round) + self.round_length.days)
  end

  def get_delinquent_users(round)
      posted_users = self.rotisserie_posts.collect {|p| p.user if p.round == round}
      missing_users = self.users - posted_users.to_a
      return missing_users.delete(author)
  end

  def change_date(value)
      self.update_attributes(:start_date => (self.start_date.to_datetime).advance(:days => value))
  end

  def crankable?
    round = self.current_round
    previous_round = (round - 1)

    current_round = self.current_round
    return (current_round > 1) && (self.get_last_assignment < current_round) && (self.rotisserie_posts.count(:all, :conditions => {:round => previous_round})) && self.open?
  end

  def notifiable?

    round = self.current_round
    tracked_round = 0
    last_tracker = NotificationTracker.last(:conditions => {:rotisserie_discussion_id => self.id})

    if !last_tracker.blank?
      tracked_round = date_to_round(self.start_date, last_tracker.created_at.to_datetime, self.round_length)
    end

    return (round > tracked_round) && round < (self.final_round + 2)

  end

  def open?
    return (self.current_round > 0) && (self.current_round <= self.final_round)
  end

  def closed?
    return self.current_round > self.final_round
  end

  def pending?
    return self.current_round < 1
  end

  #This determines if the discussion is more than midway through the current round.
  def midway?
    startdate =  self.get_round_startdate(self.current_round)
    mid = startdate.advance(:days => (self.round_length/2))
    return Time.now > mid
  end

  #This shows if there is less than one day left for the current round
  def less_than_one_day?
    current_round = self.current_round
    enddate =  self.get_round_enddate(current_round)
    if (current_round > 0) && self.open?
      return Time.now > (enddate.advance(:days => -1))
    else
      return false
    end
  end


   def activate_rotisserie

      round = self.current_round

      previous_round = (round - 1)

      if self.crankable?

      #remove discussion author
      users.delete(author)

      #get posts at random
      #random_posts = Array.new(self.posts.find(:all, :conditions => {:created_at => get_round_startdate(previous_round)..get_round_enddate(previous_round)}))
      random_posts = self.rotisserie_posts.find(:all, :conditions => {:round => previous_round})
      raise "there are no posts to rotisserie" if random_posts.empty?

      #assign one random post to each user
      users.each do |user|
        available_posts = random_posts.collect{|post| post.author.id == user.id ? nil : post}
        available_posts = available_posts.compact

        if available_posts.length > 0

          post = available_posts.rand

          RotisserieAssignment.create(:rotisserie_post_id => post.id, :user_id => user.id, :rotisserie_discussion_id => self.id, :round => round)
          #self.send_assignment_notify(user)

          #remove already assigned post
          random_posts.delete(post)

          #if there are less posts than users, start again
          random_posts = self.rotisserie_posts.to_a if random_posts.empty?

        end

      end #END users.each do |user|

      end #END round > 1

    end

  def send_discussion_notify
    type_description = "discussion_notify"

    discussion_tracker_hash = {
      :rotisserie_discussion_id => self.id,
      :notify_description => type_description
     }

    if !NotificationTracker.exists?(discussion_tracker_hash)
       Notifier.deliver_discussion_notify(self)
    end

  end

  def send_discussion_late_notify
    type_description = "discussion_late_notify"

    self.users.all(:conditions => "email_address IS NOT NULL").each do |user|
      if !self.answered_discussion?

        discussion_tracker_hash = {
          :rotisserie_discussion_id => self.id,
          :user_id => user.id,
          :notify_description => type_description
         }

        if !NotificationTracker.exists?(discussion_tracker_hash)
           Notifier.deliver_discussion_late_notify(self, user)
        end
      end
    end
  end

  def send_assignment_notify(user)
    type_description = "assignment_notify"

    if !user.email_address.blank?
      Notifier.deliver_assignment_notify(self, user)
    end
  end


  def send_assignment_late_notify
    type_description = "assignment_late_notify"
    type_description += "#-{self.current_round.to_s}"

    self.users.all(:conditions => "email_address IS NOT NULL").each do |user|

      assignments = user.get_current_assignments(self)

      if assignments.length > 0

        discussion_tracker_hash = {
          :rotisserie_discussion_id => self.id,
          :user_id => user.id,
          :notify_description => type_description
         }

        if !NotificationTracker.exists?(discussion_tracker_hash) && !user.email_address.blank?
           Notifier.deliver_assignment_late_notify(self, user)
        end
      end
    end

  end

  def send_completed_notify
    type_description = "completed_notify"

    discussion_tracker_hash = {
      :rotisserie_discussion_id => self.id,
      :notify_description => type_description
     }

    if !NotificationTracker.exists?(discussion_tracker_hash)
       Notifier.deliver_completed_notify(self)
    end

  end

  def send_all_notifications

    if !self.pending?
     if self.open?
        if self.current_round == 1
          self.send_discussion_notify
        end

        if self.less_than_one_day? && (self.current_round == 1)
          self.send_discussion_late_notify
        end

        if self.less_than_one_day? && (self.current_round > 1)
          self.send_assignment_late_notify
        end
     elsif self.closed?
        self.send_completed_notify
     end
    end

  end

  def status_report
    output = ""

    output += "<p>\n"
    output += "<b>DISCUSSION STATUS</b><br />\n"
    output += "PENDING: #{self.pending?}<br />\n"
    output += "OPEN: #{self.open?}<br />\n"
    output += "CLOSED: #{self.closed?}<br />\n"
    output += "ROUND:  #{self.current_round}<br />\n"
    output += "LESS THAN DAY:  #{self.less_than_one_day?}<br />\n"
    output += "</p>\n"

    output += "<p>\n"
    output += "<b>NOTIFICATION STATUS</b><br />\n"
    output += "CREATION: #{self.current_round == 1}<br />\n"
    output += "LATE INITIAL: #{self.less_than_one_day? && (self.current_round == 1)}<br />\n"
    output += "LATE ASSIGNMENT: #{self.less_than_one_day? && (self.current_round > 1)}<br />\n"
    output += "COMPLETION:  #{self.closed?}<br />\n"
    output += "</p>\n"

    return output

   end



end
