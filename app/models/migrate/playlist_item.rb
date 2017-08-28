class Migrate::PlaylistItem < ApplicationRecord
  belongs_to :playlist

  belongs_to :actual_object, polymorphic: true
end
