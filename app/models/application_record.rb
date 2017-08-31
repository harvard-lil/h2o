class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def klass
    self.class.to_s
  end

  def user_display
    self.user.nil? ? nil : self.user.display
  end
end
