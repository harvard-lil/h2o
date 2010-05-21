class PlaylistItem < ActiveRecord::Base
  acts_as_category :scope => :playlist, :hidden => :active
  acts_as_authorization_object

  belongs_to :resource_item, :polymorphic => true

  ITEM_TYPES = [["Basic URL", "ItemDefault"],["Youtube Video", "ItemYoutube"],["Image", "ItemImage"],["Text File", "ItemText"]]
end
