module Authorship
  def user_display
    self.user.nil? ? nil : self.user.display
  end

  def root_user_display
    self.root.user.nil? ? nil : self.root.user.display
  end
  
  def root_user_id
    self.root.user_id
  end
end
