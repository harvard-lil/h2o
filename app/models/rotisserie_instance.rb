class RotisserieInstance < ActiveRecord::Base
  acts_as_authorization_object

  has_many :rotisserie_discussions
  #has_many :roles, :foreign_key => :authorizable_id, :conditions => {:authorizable_type => self.class.to_string}
  
  validates_presence_of :title
  validates_uniqueness_of :title
end
