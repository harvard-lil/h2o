# == Schema Information
#
# Table name: frozen_items
#
#  id         :integer          not null, primary key
#  content    :text
#  version    :integer          not null
#  item_id    :integer          not null
#  item_type  :string(255)      not null
#  created_at :datetime
#  updated_at :datetime
#

class FrozenItem < ActiveRecord::Base
  validates_presence_of :content, :version, :item_type, :item_id

  belongs_to :item, :polymorphic => true
end
