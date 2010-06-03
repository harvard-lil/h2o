# == Schema Information
# Schema version: 20090828145656
#
# Table name: users
#
#  id                :integer(4)      not null, primary key
#  created_at        :datetime
#  updated_at        :datetime
#  login             :string(255)     not null
#  crypted_password  :string(255)     not null
#  password_salt     :string(255)     not null
#  persistence_token :string(255)     not null
#  login_count       :integer(4)      default(0), not null
#  last_request_at   :datetime
#  last_login_at     :datetime
#  current_login_at  :datetime
#  last_login_ip     :string(255)
#  current_login_ip  :string(255)
#

class User < ActiveRecord::Base
  acts_as_voter
  acts_as_authentic 
  acts_as_authorization_subject
  
  has_and_belongs_to_many :roles
  has_many :rotisserie_assignments

  validates_format_of_email :email_address, :allow_blank => true
  validates_inclusion_of :tz_name, :in => ActiveSupport::TimeZone::MAPPING.keys, :allow_blank => true

  MANAGEMENT_ROLES = ["owner", "editor", "user"]


  def get_current_assignments(rotisserie_discussion = nil)
    assignments_array = Array.new()

    if rotisserie_discussion.nil?
      rotisserie_assignments = self.assignments
    else
      rotisserie_assignments = RotisserieAssignment.find(:all, :conditions => {:user_id =>  self.id, :round => rotisserie_discussion.current_round, :rotisserie_discussion_id => rotisserie_discussion.id })
    end

    rotisserie_assignments.each do |assignment|
        if !assignment.responded? && assignment.open?
          assignments_array << assignment
        end
    end

    return assignments_array
  end

end
