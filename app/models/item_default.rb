class ItemDefault < ActiveRecord::Base
  belongs_to :resource_item, :polymorphic => true
end
