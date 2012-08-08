class UserCollection < ActiveRecord::Base
  belongs_to :owner, :class_name => "User"
  has_and_belongs_to_many :users
  has_and_belongs_to_many :playlists

  validates_presence_of :owner_id, :name
end
