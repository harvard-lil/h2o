class Role < ActiveRecord::Base
  #acts_as_authorization_role
  has_many :roles_users
  has_one :user, :through => :roles_users

  belongs_to :authorizable, :polymorphic => true
end
