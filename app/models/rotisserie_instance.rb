class RotisserieInstance < ActiveRecord::Base
  acts_as_authorization_object

  has_many :rotisserie_discussions
  #has_many :roles, :foreign_key => :authorizable_id, :conditions => {:authorizable_type => self.class.to_string}
  
  validates_presence_of :title
  validates_uniqueness_of :title

  ### Pulls current user from authlogic
  def current_user
    session = UserSession.find
    current_user = session && session.user
    return current_user
  end

  def admin?
    return self.accepts_role?(:admin, current_user)
  end

  def owner?
    return self.accepts_role?(:owner, current_user)
  end


end
