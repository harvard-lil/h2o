class UserCollection < ActiveRecord::Base
  has_and_belongs_to_many :users
  belongs_to :owner, :class_name => "User"

  validates_presence_of :owner_id, :name
end
