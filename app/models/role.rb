class Role < ApplicationRecord
  #acts_as_authorization_role
  has_many :roles_users
  has_one :user, :through => :roles_users

  belongs_to :authorizable, :polymorphic => true, optional: true
end
