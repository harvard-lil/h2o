class ItemDefault < ActiveRecord::Base
  include AuthUtilities
 
  acts_as_authorization_object

  has_one :playlist_item, :as => :resource_item, :dependent => :destroy
  validates_presence_of :name
  belongs_to :actual_object, :polymorphic => true
end
