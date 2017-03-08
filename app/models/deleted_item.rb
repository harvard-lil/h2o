# == Schema Information
#
# Table name: deleted_items
#
#  id         :integer          not null, primary key
#  item_id    :integer
#  item_type  :string(255)
#  deleted_at :datetime
#

class DeletedItem < ActiveRecord::Base
  def month
    self.deleted_at.strftime('%Y-%m')
  end
end
