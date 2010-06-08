class Influence < ActiveRecord::Base
  acts_as_category :scope => [:resource_id, :resource_type]
  belongs_to :resource, :polymorphic => true
end
