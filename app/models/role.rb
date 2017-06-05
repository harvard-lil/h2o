# == Schema Information
#
# Table name: roles
#
#  id                :integer          not null, primary key
#  name              :string(40)
#  authorizable_type :string(40)
#  authorizable_id   :integer
#  created_at        :datetime
#  updated_at        :datetime
#

class Role < ApplicationRecord
  #acts_as_authorization_role
  has_many :roles_users
  has_one :user, :through => :roles_users

  belongs_to :authorizable, :polymorphic => true, optional: true
end
