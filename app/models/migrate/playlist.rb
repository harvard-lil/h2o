class Migrate::Playlist < ApplicationRecord
  has_ancestry
  has_many :playlist_items
  belongs_to :user

  def migrate
    Migrate.migrate_playlist self
  end
end
