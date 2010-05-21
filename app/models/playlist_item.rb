class PlaylistItem < ActiveRecord::Base
  belongs_to :resource_item, :polymorphic => true
  acts_as_category :scope => :playlist, :hidden => :active

  ITEM_TYPES = [["Basic URL", "ItemDefault"],["Youtube Video", "ItemYoutube"],["Image", "ItemImage"],["Text File", "ItemText"]]
end
