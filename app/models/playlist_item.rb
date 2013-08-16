require 'redcloth_extensions'

class PlaylistItem < ActiveRecord::Base
  extend RedclothExtensions::ClassMethods

  validates_presence_of :name
  belongs_to :playlist
  belongs_to :actual_object, :polymorphic => true 

  def clean_type
    actual_object_type.to_s.downcase
  end

  def render_dropdown
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
