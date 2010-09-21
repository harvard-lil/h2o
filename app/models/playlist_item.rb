require 'redcloth_extensions'
require 'playlistable_extensions'
require 'ancestry_extensions'

class PlaylistItem < ActiveRecord::Base
  extend AncestryExtensions::ClassMethods
  extend PlaylistableExtensions::ClassMethods
  extend RedclothExtensions::ClassMethods

  include PlaylistableExtensions::InstanceMethods
  include AncestryExtensions::InstanceMethods
  include AuthUtilities

  before_destroy :collapse_children
  has_ancestry :orphan_strategy => :restrict

  acts_as_authorization_object

  belongs_to :resource_item, :polymorphic => true

  #This is a self-referential relationship, renamed so as to not conflict with methods exported by ancestry.
  belongs_to :playlist_item_parent, :class_name => 'PlaylistItem'

  def display_name
    (resource_item.respond_to?(:title)) ? resource_item.title : resource_item.name
  end

  alias :to_s :display_name

  ITEM_TYPES = [
    ["Basic URL", "ItemDefault"],
    ["Youtube Video", "ItemYoutube"],
    ["Image", "ItemImage"],
    ["Text File", "ItemText"],
    ["H2O Question Tool", "ItemQuestionInstance"],
    ["H2O Rotisserie", "ItemRotisserieDiscussion"],
    ["H2O Playlist", "ItemPlaylist"]
    ]

  def self.playlistable_classes
    Dir.glob(RAILS_ROOT + '/app/models/*.rb').each do |file| 
      model_name = Pathname(file).basename.to_s
      model_name = model_name[0..(model_name.length - 4)]
      model_name.camelize.constantize
    end
    # Responds to the annotatable class method with true.
    Object.subclasses_of(ActiveRecord::Base).find_all{|m| m.respond_to?(:playlistable?) && m.send(:playlistable?)}.sort{|a,b|a.class_name <=> b.class_name}
  end

end
