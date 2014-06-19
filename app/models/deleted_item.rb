class DeletedItem < ActiveRecord::Base
  def month
    self.deleted_at.strftime('%Y-%m')
  end
end
