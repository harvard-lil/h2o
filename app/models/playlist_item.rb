require 'redcloth_extensions'

class PlaylistItem < ActiveRecord::Base
  extend RedclothExtensions::ClassMethods

  validates_presence_of :name
  belongs_to :playlist
  belongs_to :actual_object, :polymorphic => true 
  validate :not_infinite

  def clean_type
    actual_object_type.to_s.downcase
  end

  def not_infinite
    return true if !self.new_record?
    return true if self.actual_object_type != 'Playlist'
    errors.add(:base, "You can't add a playlist to itself as a playlist item.") if self.actual_object_id == self.playlist_id
    errors.add(:base, "This playlist is already included as a playlist item in the playlist you are attempting to add.") if self.playlist.relation_ids.include?(self.actual_object_id)
  end

  def render_dropdown
    return false if self.actual_object.nil?

    return false if actual_object_type == "TextBlock"

    return true if actual_object_type == "Playlist"

    return true if actual_object_type == "Collage"

    if self.actual_object.respond_to?(:description)
      return true if self.actual_object.description.present?

      return true if self.description != '' && self.description != self.actual_object.description
    end

    return true if self.notes.to_s != '' && self.public_notes

    false
  end
end
