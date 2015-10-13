class FrozenItem < ActiveRecord::Base
  validates_presence_of :content, :version, :item_type, :item_id

  belongs_to :item, :polymorphic => true
end
