class PlaylistItem < ActiveRecord::Base
  belongs_to :playlist
  has_many :items, :polymorphic => true
  acts_as_category :scope => :playlist, :hidden => :active
end
