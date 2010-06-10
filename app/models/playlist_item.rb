class PlaylistItem < ActiveRecord::Base
  include AuthUtilities
  
  acts_as_category :scope => :playlist, :hidden => :active
  acts_as_authorization_object

  belongs_to :resource_item, :polymorphic => true

  ITEM_TYPES = [
    ["Basic URL", "ItemDefault"],
    ["Youtube Video", "ItemYoutube"],
    ["Image", "ItemImage"],
    ["Text File", "ItemText"],
    ["H2O Question Tool", "ItemQuestionInstance"],
    ["H2O Rotisserie", "ItemRotisserieDiscussion"],
    ["H2O Playlist", "ItemPlaylist"]
    ]
end
