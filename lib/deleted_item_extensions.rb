module DeletedItemExtensions
  extend ActiveSupport::Concern

  included do
    before_destroy :create_deleted_item
  end

  def month
    self.created_at.strftime('%Y-%m')
  end
  def create_deleted_item
    DeletedItem.create!(item_id: self.id, item_type: self.class.name, deleted_at: DateTime.now)
  end
end
