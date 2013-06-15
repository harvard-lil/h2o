require 'redcloth_extensions'
require 'ancestry_extensions'

class PlaylistItem < ActiveRecord::Base
  extend RedclothExtensions::ClassMethods

  include AncestryExtensions::InstanceMethods
  include AuthUtilities
  include Authorship

  before_destroy :collapse_children
  has_ancestry :orphan_strategy => :restrict

  acts_as_authorization_object
  acts_as_list :scope => :playlist
  belongs_to :playlist

  belongs_to :resource_item, :polymorphic => true, :dependent => :destroy

  #This is a self-referential relationship, renamed so as to not conflict with methods exported by ancestry.
  belongs_to :playlist_item_parent, :class_name => 'PlaylistItem'

  def display_name
    if !resource_item.nil?
      (resource_item.respond_to?(:title)) ? resource_item.title : resource_item.name
    else
      ''
    end
  end

  def clean_type
    resource_item_type.downcase.gsub(/^item/, '')
  end

  alias :to_s :display_name

  def render_dropdown
    return false if resource_item_type == "ItemTextBlock"

    return true if resource_item_type == "ItemPlaylist"

    return true if resource_item_type == "ItemCollage"

    if resource_item.actual_object.respond_to?(:description)
      return true if resource_item.actual_object.description.present?

      return true if resource_item.description != '' && resource_item.description != resource_item.actual_object.description
    end

    return true if self.notes.to_s != '' && self.public_notes

    false
  end
end
