module AuthUtilities

  ### Pulls current user from authlogic
  def current_user
    session = UserSession.find
    current_user = session && session.user
    return current_user
  end

  def admin?
    return self.accepts_role?(:admin, current_user)
  end

  def owner?
    return self.accepts_role?(:owner, current_user)
  end

end
